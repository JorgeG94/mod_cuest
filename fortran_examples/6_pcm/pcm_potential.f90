! ============================================================================
!  pcm_potential.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/6_pcm/pcm_potential/main.c
!
!  Computes the PCM (polarizable continuum model) potential matrix and the
!  PCM dielectric energy. The induced surface charges on the solute cavity are
!  found with a preconditioned conjugate gradient solve; the converged charges
!  and the convergence diagnostics come back alongside the potential matrix.
!
!  Structure follows the C sample call for call:
!    per-atom cavity parameters -> handle -> AO shells -> AO basis
!           -> AO pair list -> OE integral plan -> PCM integral plan
!           -> PCM potential compute -> results query
!
!  The cavity is described entirely by four HOST arrays, one entry per atom:
!    numAngularPointsPerAtom  Lebedev order of that atom's sphere
!                             (110 for hydrogen, 194 otherwise, as in the C)
!    zetas                    York-Karplus quadrature exponent for that order
!    atomicRadii              1.2 x Bondi radius, in bohr
!    effectiveNuclearCharges  +Z (the parsed charges are stored as -Z)
!  The density, the charge vectors and the potential matrix are DEVICE buffers.
!
!  As in the C sample there is no real density available, so a synthetic
!  symmetric matrix built from a Box-Muller transform of glibc rand() is
!  substituted; libc's srand()/rand() are called directly so the pseudo-density
!  is bit-identical to the C sample's.
!
!  Usage:  ./pcm_potential <xyz_file> <gbs_file>
! ============================================================================
program pcm_potential
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use ao_shells
    use pcm_helper
    implicit none

    !> glibc's rand()/srand(). Used verbatim so the synthetic density matches
    !  the C sample's element for element -- a Fortran RNG would not.
    interface
        subroutine c_srand(seed) bind(C, name="srand")
            import :: c_int
            integer(c_int), value :: seed
        end subroutine c_srand
        integer(c_int) function c_rand() bind(C, name="rand")
            import :: c_int
        end function c_rand
    end interface

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: pl_par = c_null_ptr, plan_par = c_null_ptr
    type(c_ptr) :: pcm_par = c_null_ptr, pot_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: pcm_plan = c_null_ptr, pcm_results = c_null_ptr
    type(c_ptr) :: d_d = c_null_ptr, d_inq = c_null_ptr
    type(c_ptr) :: d_outq = c_null_ptr, d_v_pcm = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_pl, ws_plan, ws_pcm, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    real(c_double),     parameter :: PI = 3.14159265358979323846d0
    !> RAND_MAX on glibc; the C helper divides by RAND_MAX + 2.0.
    real(c_double),     parameter :: RAND_DIV = 2147483647.0d0 + 2.0d0
    !> Dielectric constant of the continuum, as in the C sample (water).
    real(c_double),     parameter :: EPSILON_SOLVENT = 80.0d0

    ! ---- per-atom cavity description (HOST) --------------------------------
    integer(c_int64_t), allocatable         :: num_angular_points(:)
    real(c_double),     allocatable, target :: zetas(:)
    real(c_double),     allocatable, target :: atomic_radii(:)
    real(c_double),     allocatable, target :: eff_nuclear_charges(:)

    integer(c_int64_t) :: nao = 0, npoint = 0, num_atoms, nang
    integer(c_int64_t) :: i
    real(c_double), allocatable :: h_mat(:), h_q(:)

    ! ---- PCM convergence results (TARGET: cuestResultsQuery takes void*) ----
    real(c_double),     target :: pcm_energy = 0.0d0
    real(c_double),     target :: converged_residual = 0.0d0
    integer(c_int64_t), target :: num_iterations = 0_c_int64_t
    integer(c_int32_t), target :: converged = 0_c_int32_t

    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST PCM potential (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms
    write(*,'(A,I0)') "  atoms    : ", num_atoms

    ! ---- 2. per-atom PCM cavity parameters ---------------------------------
    ! Bondi radii (scaled 1.2x) and the York-Karplus zetas come from
    ! pcm_helper; the angular grid convention (110 points for hydrogen, 194
    ! for everything heavier) is the C sample's.
    allocate(num_angular_points(num_atoms))
    allocate(zetas(num_atoms))
    allocate(atomic_radii(num_atoms))
    allocate(eff_nuclear_charges(num_atoms))
    do i = 1_c_int64_t, num_atoms
        if (trim(xyz%symbols(int(i))) == "H") then
            nang = 110_c_int64_t
        else
            nang = 194_c_int64_t
        end if
        num_angular_points(i)  = nang
        zetas(i)               = pcm_angular_points_to_zeta(nang)
        atomic_radii(i)        = &
            symbol_to_scaled_bondi_radius_bohr(xyz%symbols(int(i)))
        ! chargesCPU holds -Z, so the effective nuclear charge is its negative.
        eff_nuclear_charges(i) = -xyz%charges_cpu(int(i))
    end do

    ! ---- 3. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 4. AO shells ------------------------------------------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd)
    write(*,'(A,I0)') "  shells   : ", sd%num_shells_total

    ! ---- 5. AO basis (query -> allocate -> create) -------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersCreate(basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     d_persist, d_temp, basis), "AOBasisCreateWorkspaceQuery")
    call ws_alloc(ws_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     ws_basis, ws_tmp, basis), "cuestAOBasisCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersDestroy(basis)")
    call free_ao_shell_data(sd)

    ! ---- 6. AO pair list (host coordinates enter here) ---------------------
    call cuest_check(cuestParametersCreate(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersCreate(pair list)")
    call make_pair_list()
    call cuest_check(cuestParametersDestroy(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersDestroy(pair list)")

    ! ---- 7. one-electron integral plan -------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_OEINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(OE plan)")
    call cuest_check(cuestOEIntPlanCreateWorkspaceQuery(handle, basis, pair_list, &
                     plan_par, d_persist, d_temp, plan), "OEIntPlanWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestOEIntPlanCreate(handle, basis, pair_list, plan_par, &
                     ws_plan, ws_tmp, plan), "cuestOEIntPlanCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_OEINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(OE plan)")

    ! ---- 8. PCM integral plan (builds the cavity surface) ------------------
    call cuest_check(cuestParametersCreate(CUEST_PCMINTPLAN_PARAMETERS, pcm_par), &
                     "ParametersCreate(PCM plan)")
    call make_pcm_plan()
    call cuest_check(cuestParametersDestroy(CUEST_PCMINTPLAN_PARAMETERS, pcm_par), &
                     "ParametersDestroy(PCM plan)")

    ! ---- 9. sizes ----------------------------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    write(*,'(A,I0)') "  nao      : ", nao

    ! npoint is the sum of numAngularPointsPerAtom.
    call cuest_check(cuest_query_i64(handle, CUEST_PCMINTPLAN, pcm_plan, &
                     CUEST_PCMINTPLAN_NUM_POINT, npoint), "query NUM_POINT")
    write(*,'(A,I0)') "  npoint   : ", npoint

    ! ---- 10. device buffers -------------------------------------------------
    d_d     = dev_alloc(nao*nao)
    d_inq   = dev_alloc(npoint)
    d_outq  = dev_alloc(npoint)
    d_v_pcm = dev_alloc(nao*nao)
    allocate(h_mat(nao*nao))
    allocate(h_q(npoint))

    ! Populate the density with the same synthetic values the C sample uses.
    call fill_symmetric_matrix(h_mat, nao)
    call host_to_dev(d_d, h_mat, nao*nao)

    ! Zero the initial charge guess; the PCG solver finds the converged charges.
    call cuda_ck(cudaMemset(d_inq, 0_c_int, int(npoint, c_size_t)*8_c_size_t), &
                 "cudaMemset(inQ)")

    ! ---- 11. PCM potential --------------------------------------------------
    call cuest_check(cuestResultsCreate(CUEST_PCM_RESULTS, pcm_results), &
                     "ResultsCreate(PCM)")

    call cuest_check(cuestParametersCreate( &
                     CUEST_PCMPOTENTIALCOMPUTE_PARAMETERS, pot_par), &
                     "ParametersCreate(PCM potential)")
    call cuest_check(cuestPCMPotentialComputeWorkspaceQuery(handle, pcm_plan, &
                     pot_par, d_temp, d_d, d_inq, d_outq, pcm_results, d_v_pcm), &
                     "PCMPotentialComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestPCMPotentialCompute(handle, pcm_plan, pot_par, ws_tmp, &
                     d_d, d_inq, d_outq, pcm_results, d_v_pcm), &
                     "cuestPCMPotentialCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_PCMPOTENTIALCOMPUTE_PARAMETERS, pot_par), &
                     "ParametersDestroy(PCM potential)")

    ! d_outq now holds the converged surface charges; swapping inQ and outQ
    ! would warm-start the next SCF cycle's solve.

    ! ---- 12. convergence information ---------------------------------------
    call cuest_check(cuestResultsQuery(CUEST_PCM_RESULTS, pcm_results, &
                     CUEST_PCMRESULT_PCM_DIELECTRIC_ENERGY, &
                     c_loc(pcm_energy), c_sizeof(pcm_energy)), &
                     "ResultsQuery(dielectric energy)")
    call cuest_check(cuestResultsQuery(CUEST_PCM_RESULTS, pcm_results, &
                     CUEST_PCMRESULT_CONVERGED_RESIDUAL, &
                     c_loc(converged_residual), c_sizeof(converged_residual)), &
                     "ResultsQuery(converged residual)")
    call cuest_check(cuestResultsQuery(CUEST_PCM_RESULTS, pcm_results, &
                     CUEST_PCMRESULT_NUM_ITERATIONS_TAKEN, &
                     c_loc(num_iterations), c_sizeof(num_iterations)), &
                     "ResultsQuery(iterations taken)")
    call cuest_check(cuestResultsQuery(CUEST_PCM_RESULTS, pcm_results, &
                     CUEST_PCMRESULT_CONVERGED, &
                     c_loc(converged), c_sizeof(converged)), &
                     "ResultsQuery(converged)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    write(*,'(A,F20.12,A)') "PCM dielectric energy:  ", pcm_energy, " Eh"
    write(*,'(A,ES20.12)')  "PCG converged residual: ", converged_residual
    write(*,'(A,I0)')       "PCG iterations taken:   ", num_iterations
    if (converged /= 0_c_int32_t) then
        write(*,'(A)') "PCG converged:          yes"
    else
        write(*,'(A)') "PCG converged:          no"
    end if

    ! ---- 13. report ---------------------------------------------------------
    ! The density is an input, but a synthetic one: if the two RNG streams ever
    ! diverge the potential would differ for a reason unrelated to cuEST.
    write(*,'(A)') ""
    call matrix_report("D (synthetic density)", h_mat, nao)
    call dev_to_host(h_mat, d_v_pcm, nao*nao)
    call matrix_report("V_PCM (PCM potential matrix)", h_mat, nao)
    call dev_to_host(h_q, d_outq, npoint)
    call array_report("q (converged surface charges)", h_q, npoint)
    call scalar_report("PCM dielectric energy", pcm_energy)
    call scalar_report("PCG converged residual [informational]", converged_residual)
    call scalar_report("PCG iterations taken", real(num_iterations, c_double))
    call scalar_report("PCG converged flag", real(converged, c_double))

    ! ---- 14. teardown -------------------------------------------------------
    deallocate(h_mat)
    deallocate(h_q)
    call dev_free(d_d)
    call dev_free(d_inq)
    call dev_free(d_outq)
    call dev_free(d_v_pcm)

    ist = cuestResultsDestroy(CUEST_PCM_RESULTS, pcm_results)
    ist = cuestPCMIntPlanDestroy(pcm_plan)
    call ws_free(ws_pcm)
    ist = cuestOEIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestAOPairListDestroy(pair_list)
    call ws_free(ws_pl)
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    ist = cuestDestroy(handle)

    deallocate(num_angular_points)
    deallocate(zetas)
    deallocate(atomic_radii)
    deallocate(eff_nuclear_charges)
    call free_parsed_xyz(xyz)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    !> The pair list takes HOST coordinates, so C_LOC needs a TARGET actual
    !  argument; wrapping it here keeps the main flow readable.
    subroutine make_pair_list()
        real(c_double), parameter :: TOL = 1.0d-14
        call cuest_check(cuestAOPairListCreateWorkspaceQuery(handle, basis, &
                         num_atoms, c_loc(xyz%xyz_cpu), TOL, pl_par, &
                         d_persist, d_temp, pair_list), &
                         "AOPairListCreateWorkspaceQuery")
        call ws_alloc(ws_pl, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestAOPairListCreate(handle, basis, num_atoms, &
                         c_loc(xyz%xyz_cpu), TOL, pl_par, ws_pl, ws_tmp, &
                         pair_list), "cuestAOPairListCreate")
        call ws_free(ws_tmp)
    end subroutine make_pair_list

    !> The PCM plan's cavity description is four HOST arrays: the angular point
    !  counts pass as an array (the binding declares them dimension(*)), the
    !  three double arrays pass as C_LOC addresses and so need TARGET.
    subroutine make_pcm_plan()
        call cuest_check(cuestPCMIntPlanCreateWorkspaceQuery(handle, plan, &
                         pcm_par, d_persist, d_temp, num_angular_points, &
                         EPSILON_SOLVENT, c_loc(zetas), c_loc(atomic_radii), &
                         c_loc(eff_nuclear_charges), pcm_plan), &
                         "PCMIntPlanCreateWorkspaceQuery")
        call ws_alloc(ws_pcm, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestPCMIntPlanCreate(handle, plan, pcm_par, &
                         ws_pcm, ws_tmp, num_angular_points, &
                         EPSILON_SOLVENT, c_loc(zetas), c_loc(atomic_radii), &
                         c_loc(eff_nuclear_charges), pcm_plan), &
                         "cuestPCMIntPlanCreate")
        call ws_free(ws_tmp)
    end subroutine make_pcm_plan

    !> Port of the sample's fill_symmetric_matrix(): a symmetric N x N matrix
    !  of standard normal deviates, generated by a Box-Muller transform of
    !  consecutive rand() values after srand(0).
    !
    !  Row-major flat storage, so element (i,j) with 0-based i,j lives at
    !  index i*N + j + 1.
    subroutine fill_symmetric_matrix(a, n)
        real(c_double),     intent(out) :: a(:)
        integer(c_int64_t), intent(in)  :: n
        integer(c_int64_t) :: ii, jj
        real(c_double) :: u1, u2, v
        call c_srand(0_c_int)
        do ii = 0_c_int64_t, n - 1_c_int64_t
            do jj = 0_c_int64_t, ii
                u1 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                u2 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                v = sqrt(-2.0d0 * log(u1)) * cos(2.0d0 * PI * u2)
                a(ii*n + jj + 1_c_int64_t) = v
                a(jj*n + ii + 1_c_int64_t) = v
            end do
        end do
    end subroutine fill_symmetric_matrix

    !> Push `n` doubles from a host array to a device buffer. C_LOC needs a
    !  TARGET dummy, hence the wrapper.
    subroutine host_to_dev(dev, host, n)
        type(c_ptr),        intent(in) :: dev
        real(c_double),     intent(in), target :: host(:)
        integer(c_int64_t), intent(in) :: n
        call cuda_ck(cudaMemcpy(dev, c_loc(host), &
                     int(n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                     "cudaMemcpy(H2D density)")
    end subroutine host_to_dev

end program pcm_potential
