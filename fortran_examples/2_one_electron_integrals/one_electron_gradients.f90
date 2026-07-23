! ============================================================================
!  one_electron_gradients.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/2_one_electron_integrals/
!    one_electron_gradients/main.c
!
!  Computes the nuclear derivatives of the overlap (dS/dR) and kinetic (dT/dR)
!  integrals, contracted with a density matrix. cuEST never exposes the raw
!  derivative integrals: the contraction with a (pseudo-)density is part of the
!  call, and the result is a numAtoms x 3 gradient array.
!
!  As in the C sample there is no real density available, so a synthetic
!  symmetric matrix built from a Box-Muller transform of rand() is substituted.
!  The port calls libc's srand()/rand() directly rather than a Fortran RNG, so
!  the pseudo-density is bit-identical to the C sample's and the gradients are
!  therefore directly comparable.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> AO pair list -> OE integral plan
!           -> synthetic density -> dS/dR, dT/dR into device buffers
!
!  Usage:  ./one_electron_gradients <xyz_file> <gbs_file>
! ============================================================================
program one_electron_gradients
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
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
    type(c_ptr) :: ds_par = c_null_ptr, dt_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_dsdr = c_null_ptr, d_dtdr = c_null_ptr, d_d = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    real(c_double),     parameter :: PI = 3.14159265358979323846d0
    !> RAND_MAX on glibc; the C helper divides by RAND_MAX + 2.0.
    real(c_double),     parameter :: RAND_DIV = 2147483647.0d0 + 2.0d0

    integer(c_int64_t) :: nao = 0, num_atoms, ngrad
    real(c_double), allocatable :: h_grad(:), h_den(:)
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST one-electron gradients (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms
    ngrad = 3_c_int64_t * num_atoms
    write(*,'(A,I0)') "  atoms    : ", num_atoms

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. AO shells ------------------------------------------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd)
    write(*,'(A,I0)') "  shells   : ", sd%num_shells_total

    ! ---- 4. AO basis (query -> allocate -> create) -------------------------
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

    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    write(*,'(A,I0)') "  nao      : ", nao

    ! ---- 5. AO pair list (host coordinates enter here) ---------------------
    call cuest_check(cuestParametersCreate(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersCreate(pair list)")
    call make_pair_list()
    call cuest_check(cuestParametersDestroy(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersDestroy(pair list)")

    ! ---- 6. one-electron integral plan -------------------------------------
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

    ! ---- 7. device buffers: two gradients plus the density -----------------
    d_dsdr = dev_alloc(ngrad)
    d_dtdr = dev_alloc(ngrad)
    d_d    = dev_alloc(nao*nao)
    allocate(h_grad(ngrad))
    allocate(h_den(nao*nao))

    ! Fill the density with the same synthetic values the C sample uses.
    call fill_symmetric_matrix(h_den, nao)
    call host_to_dev(d_d, h_den, nao*nao)

    ! ---- 8. overlap derivative ---------------------------------------------
    call cuest_check(cuestParametersCreate( &
                     CUEST_OVERLAPDERIVATIVECOMPUTE_PARAMETERS, ds_par), &
                     "ParametersCreate(overlap derivative)")
    call cuest_check(cuestOverlapDerivativeComputeWorkspaceQuery(handle, plan, &
                     ds_par, d_temp, d_d, d_dsdr), &
                     "OverlapDerivativeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestOverlapDerivativeCompute(handle, plan, ds_par, ws_tmp, &
                     d_d, d_dsdr), "cuestOverlapDerivativeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_OVERLAPDERIVATIVECOMPUTE_PARAMETERS, ds_par), &
                     "ParametersDestroy(overlap derivative)")

    ! ---- 9. kinetic derivative ---------------------------------------------
    call cuest_check(cuestParametersCreate( &
                     CUEST_KINETICDERIVATIVECOMPUTE_PARAMETERS, dt_par), &
                     "ParametersCreate(kinetic derivative)")
    call cuest_check(cuestKineticDerivativeComputeWorkspaceQuery(handle, plan, &
                     dt_par, d_temp, d_d, d_dtdr), &
                     "KineticDerivativeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestKineticDerivativeCompute(handle, plan, dt_par, ws_tmp, &
                     d_d, d_dtdr), "cuestKineticDerivativeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_KINETICDERIVATIVECOMPUTE_PARAMETERS, dt_par), &
                     "ParametersDestroy(kinetic derivative)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 10. report ---------------------------------------------------------
    ! The density is reported too: it is an input, but a synthetic one, and if
    ! the two RNG streams ever diverge the gradients would differ for a reason
    ! that has nothing to do with cuEST.
    write(*,'(A)') ""
    call matrix_report("D (synthetic density)", h_den, nao)
    call dev_to_host(h_grad, d_dsdr, ngrad)
    call array_report("dS/dR (overlap gradient)", h_grad, ngrad)
    call dev_to_host(h_grad, d_dtdr, ngrad)
    call array_report("dT/dR (kinetic gradient)", h_grad, ngrad)

    ! ---- 11. teardown ------------------------------------------------------
    deallocate(h_grad)
    deallocate(h_den)
    call dev_free(d_dsdr)
    call dev_free(d_dtdr)
    call dev_free(d_d)

    ist = cuestOEIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestAOPairListDestroy(pair_list)
    call ws_free(ws_pl)
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    call free_ao_shell_data(sd)
    ist = cuestDestroy(handle)
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

    !> Port of the sample's fill_symmetric_matrix(): a symmetric N x N matrix
    !  of standard normal deviates, generated by a Box-Muller transform of
    !  consecutive rand() values after srand(0).
    !
    !  Row-major flat storage, so element (i,j) with 0-based i,j lives at
    !  index i*N + j + 1.
    subroutine fill_symmetric_matrix(a, n)
        real(c_double),     intent(out) :: a(:)
        integer(c_int64_t), intent(in)  :: n
        integer(c_int64_t) :: i, j
        real(c_double) :: u1, u2, v
        call c_srand(0_c_int)
        do i = 0_c_int64_t, n - 1_c_int64_t
            do j = 0_c_int64_t, i
                u1 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                u2 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                v = sqrt(-2.0d0 * log(u1)) * cos(2.0d0 * PI * u2)
                a(i*n + j + 1_c_int64_t) = v
                a(j*n + i + 1_c_int64_t) = v
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

end program one_electron_gradients
