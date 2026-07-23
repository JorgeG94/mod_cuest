! ============================================================================
!  local_xc_gradient.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/4_exchange_correlation/
!    local_xc_gradient/main.c
!
!  Evaluates the nuclear derivative of the exchange-correlation energy for a
!  PBE functional on an unpruned (75, 302) direct-product molecular grid, first
!  restricted (RKS) and then unrestricted (UKS). The derivatives account for
!  motion of the basis function centres, the grid centres and the Becke
!  weights.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> atom grids -> molecular grid
!           -> XC integral plan (PBE) -> RKS gradient -> UKS gradient
!
!  The C sample has no converged SCF to draw orbitals from, so it synthesises
!  the occupied MO coefficient matrices with fill_matrix(): Box-Muller normal
!  deviates from libc rand() after srand(0). This port calls the very same
!  libc srand()/rand() through iso_c_binding, in the same order, so the inputs
!  are bit-identical to the C reference rather than merely similar.
!
!  Difference from the C sample: it computes the gradients and exits without
!  printing anything. This port prints a numeric fingerprint of the inputs and
!  the results.
!
!  Usage:  ./local_xc_gradient <xyz_file> <gbs_file>
! ============================================================================
program local_xc_gradient
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
    use grid_helper
    implicit none

    !> libc's pseudo-random generator. The C sample fills its synthetic MO
    !  coefficients from rand() after srand(0); binding to the very same
    !  routines makes the random stream identical rather than merely similar.
    interface
        subroutine c_srand(seed) bind(C, name="srand")
            import :: c_int
            integer(c_int), value :: seed
        end subroutine c_srand
        integer(c_int) function c_rand() bind(C, name="rand")
            import :: c_int
        end function c_rand
    end interface

    type(parsed_xyz_t),     target :: xyz
    type(ao_shell_data_t),  target :: sd
    type(atom_grid_data_t)         :: gd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: mgrid_par = c_null_ptr, plan_par = c_null_ptr
    type(c_ptr) :: rks_par = c_null_ptr, uks_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, mgrid = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_grad = c_null_ptr, d_cocc = c_null_ptr
    type(c_ptr) :: d_grad_uks = c_null_ptr
    type(c_ptr) :: d_cocc_a = c_null_ptr, d_cocc_b = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
    type(cuestWorkspace_t) :: ws_basis, ws_grid, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t), parameter :: NUM_RADIAL  = 75_c_int64_t
    integer(c_int64_t), parameter :: NUM_ANGULAR = 302_c_int64_t

    integer(c_int64_t) :: nao = 0, nocc = 0, nocc_a = 0, nocc_b = 0, num_atoms
    real(c_double), allocatable :: h_g(:), h_c(:)
    integer(c_int) :: ist
    integer :: i

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST local XC gradient (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry --------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms
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

    ! ---- 4. AO basis -------------------------------------------------------
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

    ! ---- 5. atom grids -- unpruned (75, 302), Ahlrichs radial quadrature ---
    call form_direct_product_atom_grid(handle, xyz, NUM_RADIAL, NUM_ANGULAR, gd)

    ! ---- 6. molecular grid (HOST coordinates, HOST atom grid array) --------
    call cuest_check(cuestParametersCreate(CUEST_MOLECULARGRID_PARAMETERS, mgrid_par), &
                     "ParametersCreate(molecular grid)")
    call make_molecular_grid()
    call cuest_check(cuestParametersDestroy(CUEST_MOLECULARGRID_PARAMETERS, mgrid_par), &
                     "ParametersDestroy(molecular grid)")

    ! The atom grids are not needed once the molecular grid exists.
    call free_atom_grid_data(gd)

    ! ---- 7. XC integral plan for PBE ---------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(XC plan)")
    call cuest_check(cuestXCIntPlanCreateWorkspaceQuery(handle, basis, mgrid, &
                     CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_PBE, plan_par, &
                     d_persist, d_temp, plan), "XCIntPlanCreateWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestXCIntPlanCreate(handle, basis, mgrid, &
                     CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_PBE, plan_par, &
                     ws_plan, ws_tmp, plan), "cuestXCIntPlanCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(XC plan)")

    ! ---- 8. dimensions -----------------------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    write(*,'(A,I0)') "  nao      : ", nao

    ! nocc for a neutral molecule; charges are stored as -Z, so -1*charge = Z
    nocc = 0
    do i = 1, int(num_atoms)
        nocc = nocc + int(-1.0d0 * xyz%charges_cpu(i), c_int64_t)
    end do
    nocc = nocc / 2
    write(*,'(A,I0)') "  nocc     : ", nocc

    ! ---- 9. RKS exchange-correlation gradient ------------------------------
    d_grad = dev_alloc(num_atoms*3)
    d_cocc = dev_alloc(nocc*nao)
    call fill_matrix(d_cocc, nocc, nao)

    call cuest_check(cuestParametersCreate(CUEST_XCDERIVATIVERKSCOMPUTE_PARAMETERS, &
                     rks_par), "ParametersCreate(RKS derivative)")

    ! The memory used while evaluating the derivative is capped by a workspace
    ! descriptor; 2 GB is the value the C sample uses and a reasonable default.
    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestXCDerivativeRKSComputeWorkspaceQuery(handle, plan, &
                     rks_par, var_buf, d_temp, nocc, d_cocc, d_grad), &
                     "XCDerivativeRKSComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestXCDerivativeRKSCompute(handle, plan, rks_par, var_buf, &
                     ws_tmp, nocc, d_cocc, d_grad), "cuestXCDerivativeRKSCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_XCDERIVATIVERKSCOMPUTE_PARAMETERS, &
                     rks_par), "ParametersDestroy(RKS derivative)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    write(*,'(A)') ""
    allocate(h_g(num_atoms*3), h_c(nocc*nao))
    call dev_to_host(h_c, d_cocc, nocc*nao)
    call array_report("Cocc (RKS MO coefficients)", h_c, nocc*nao)
    call dev_to_host(h_g, d_grad, num_atoms*3)
    call array_report("dExc/dR (RKS)", h_g, num_atoms*3)
    deallocate(h_c)

    call dev_free(d_grad)
    call dev_free(d_cocc)

    ! ---- 10. UKS exchange-correlation gradient -----------------------------
    !
    ! A doublet cation: one fewer beta electron than alpha.
    nocc_a = nocc
    nocc_b = nocc - 1

    d_grad_uks = dev_alloc(num_atoms*3)
    d_cocc_a   = dev_alloc(nocc_a*nao)
    d_cocc_b   = dev_alloc(nocc_b*nao)
    call fill_matrix(d_cocc_a, nocc_a, nao)
    call fill_matrix(d_cocc_b, nocc_b, nao)

    call cuest_check(cuestParametersCreate(CUEST_XCDERIVATIVEUKSCOMPUTE_PARAMETERS, &
                     uks_par), "ParametersCreate(UKS derivative)")

    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestXCDerivativeUKSComputeWorkspaceQuery(handle, plan, &
                     uks_par, var_buf, d_temp, nocc_a, nocc_b, d_cocc_a, &
                     d_cocc_b, d_grad_uks), &
                     "XCDerivativeUKSComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestXCDerivativeUKSCompute(handle, plan, uks_par, var_buf, &
                     ws_tmp, nocc_a, nocc_b, d_cocc_a, d_cocc_b, d_grad_uks), &
                     "cuestXCDerivativeUKSCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_XCDERIVATIVEUKSCOMPUTE_PARAMETERS, &
                     uks_par), "ParametersDestroy(UKS derivative)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    allocate(h_c(nocc_a*nao))
    call dev_to_host(h_c, d_cocc_a, nocc_a*nao)
    call array_report("CoccA (UKS alpha MO coefficients)", h_c, nocc_a*nao)
    deallocate(h_c)
    allocate(h_c(nocc_b*nao))
    call dev_to_host(h_c, d_cocc_b, nocc_b*nao)
    call array_report("CoccB (UKS beta MO coefficients)", h_c, nocc_b*nao)
    deallocate(h_c)
    call dev_to_host(h_g, d_grad_uks, num_atoms*3)
    call array_report("dExc/dR (UKS)", h_g, num_atoms*3)

    ! ---- 11. teardown ------------------------------------------------------
    deallocate(h_g)
    call dev_free(d_grad_uks)
    call dev_free(d_cocc_a)
    call dev_free(d_cocc_b)

    ist = cuestXCIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestMolecularGridDestroy(mgrid)
    call ws_free(ws_grid)
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    !> The molecular grid takes HOST coordinates, so C_LOC needs a TARGET
    !  actual argument; wrapping it here keeps the main flow readable.
    subroutine make_molecular_grid()
        call cuest_check(cuestMolecularGridCreateWorkspaceQuery(handle, &
                         num_atoms, gd%grids, c_loc(xyz%xyz_cpu), mgrid_par, &
                         d_persist, d_temp, mgrid), &
                         "MolecularGridCreateWorkspaceQuery")
        call ws_alloc(ws_grid, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestMolecularGridCreate(handle, num_atoms, gd%grids, &
                         c_loc(xyz%xyz_cpu), mgrid_par, ws_grid, ws_tmp, mgrid), &
                         "cuestMolecularGridCreate")
        call ws_free(ws_tmp)
    end subroutine make_molecular_grid

    !> M x N row-major matrix of N(0,1) deviates, copied to the device.
    !  Exact transcription of the C sample's fill_matrix().
    subroutine fill_matrix(dev, m, n)
        type(c_ptr),        intent(in) :: dev
        integer(c_int64_t), intent(in) :: m, n
        real(c_double), allocatable, target :: atmp(:)
        real(c_double), parameter :: PI = 3.14159265358979323846d0
        real(c_double), parameter :: SCALE = 2147483647.0d0 + 2.0d0  ! RAND_MAX+2
        real(c_double) :: u1, u2
        integer(c_int64_t) :: ii, jj, ij
        allocate(atmp(m*n))
        call c_srand(0_c_int)
        ij = 0
        do ii = 1, m
            do jj = 1, n
                ij = ij + 1
                u1 = (real(c_rand(), c_double) + 1.0d0) / SCALE
                u2 = (real(c_rand(), c_double) + 1.0d0) / SCALE
                atmp(ij) = sqrt(-2.0d0 * log(u1)) * cos(2.0d0 * PI * u2)
            end do
        end do
        call cuda_ck(cudaMemcpy(dev, c_loc(atmp), &
                     int(m*n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                     "cudaMemcpy(fill_matrix H2D)")
        deallocate(atmp)
    end subroutine fill_matrix

end program local_xc_gradient
