! ============================================================================
!  nonlocal_xc_potential.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/4_exchange_correlation/
!    nonlocal_xc_potential/main.c
!
!  Evaluates the VV10 nonlocal correlation energy and potential on an unpruned
!  (75, 302) direct-product molecular grid, first restricted (RKS) and then
!  unrestricted (UKS).
!
!  Two things differ from the local sample:
!    * the XC integral plan is created with the HF "functional", i.e. with no
!      local functional at all -- only the nonlocal part is wanted here;
!    * the local part of the XC potential inherits its parameters from the
!      plan, but the nonlocal part must be configured explicitly, so the VV10
!      scale/C/b coefficients are set on the compute parameter objects.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> atom grids -> molecular grid
!           -> XC integral plan (HF) -> RKS VV10 Enl/Vnl -> UKS VV10 Enl/Vnl
!
!  Note the UKS variant produces a SINGLE potential matrix, not one per spin.
!
!  The C sample has no converged SCF to draw orbitals from, so it synthesises
!  the occupied MO coefficient matrices with fill_matrix(): Box-Muller normal
!  deviates from libc rand() after srand(0). This port calls the very same
!  libc srand()/rand() through iso_c_binding, in the same order, so the inputs
!  are bit-identical to the C reference rather than merely similar.
!
!  Difference from the C sample: it computes the results and exits without
!  printing anything. This port prints a numeric fingerprint of each.
!
!  Usage:  ./nonlocal_xc_potential <xyz_file> <gbs_file>
! ============================================================================
program nonlocal_xc_potential
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
    type(c_ptr) :: vv10_rks_par = c_null_ptr, vv10_uks_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, mgrid = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_vxc = c_null_ptr, d_cocc = c_null_ptr
    type(c_ptr) :: d_vxc_uks = c_null_ptr
    type(c_ptr) :: d_cocc_a = c_null_ptr, d_cocc_b = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
    type(cuestWorkspace_t) :: ws_basis, ws_grid, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t), parameter :: NUM_RADIAL  = 75_c_int64_t
    integer(c_int64_t), parameter :: NUM_ANGULAR = 302_c_int64_t

    integer(c_int64_t) :: nao = 0, nocc = 0, nocc_a = 0, nocc_b = 0, num_atoms
    real(c_double), target :: exc, exc_uks
    real(c_double), target :: vv10_scale, vv10_c, vv10_b
    real(c_double), allocatable :: h_mat(:), h_c(:)
    integer(c_int) :: ist
    integer :: i

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST nonlocal XC potential (Fortran port) -- headers v", &
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

    ! ---- 7. XC integral plan with NO local functional ----------------------
    call cuest_check(cuestParametersCreate(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(XC plan)")
    call cuest_check(cuestXCIntPlanCreateWorkspaceQuery(handle, basis, mgrid, &
                     CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_HF, plan_par, &
                     d_persist, d_temp, plan), "XCIntPlanCreateWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestXCIntPlanCreate(handle, basis, mgrid, &
                     CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_HF, plan_par, &
                     ws_plan, ws_tmp, plan), "cuestXCIntPlanCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(XC plan)")

    ! ---- 8. RKS nonlocal (VV10) parameters ---------------------------------
    call cuest_check(cuestParametersCreate(CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS, &
                     vv10_rks_par), "ParametersCreate(VV10 RKS)")

    vv10_scale = 1.0d0
    vv10_c     = 0.01d0
    vv10_b     = 6.0d0

    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS, vv10_rks_par, &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS_VV10_SCALE, &
        c_loc(vv10_scale), c_sizeof(vv10_scale)), "Configure(VV10 RKS scale)")
    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS, vv10_rks_par, &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS_VV10_C, &
        c_loc(vv10_c), c_sizeof(vv10_c)), "Configure(VV10 RKS C)")
    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS, vv10_rks_par, &
        CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS_VV10_B, &
        c_loc(vv10_b), c_sizeof(vv10_b)), "Configure(VV10 RKS b)")

    ! ---- 9. dimensions -----------------------------------------------------
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

    ! ---- 10. RKS nonlocal energy and potential -----------------------------
    exc = 0.0d0
    d_vxc  = dev_alloc(nao*nao)
    d_cocc = dev_alloc(nocc*nao)
    call fill_matrix(d_cocc, nocc, nao)

    ! The memory used while evaluating Vxc is capped by a workspace descriptor;
    ! 2 GB is the value the C sample uses and a reasonable default.
    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestNonlocalXCPotentialRKSComputeWorkspaceQuery(handle, &
                     plan, vv10_rks_par, var_buf, d_temp, nocc, d_cocc, &
                     c_loc(exc), d_vxc), &
                     "NonlocalXCPotentialRKSComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestNonlocalXCPotentialRKSCompute(handle, plan, &
                     vv10_rks_par, var_buf, ws_tmp, nocc, d_cocc, c_loc(exc), &
                     d_vxc), "cuestNonlocalXCPotentialRKSCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_NONLOCALXCPOTENTIALRKSCOMPUTE_PARAMETERS, &
                     vv10_rks_par), "ParametersDestroy(VV10 RKS)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    write(*,'(A)') ""
    allocate(h_mat(nao*nao), h_c(nocc*nao))
    call dev_to_host(h_c, d_cocc, nocc*nao)
    call array_report("Cocc (RKS MO coefficients)", h_c, nocc*nao)
    call scalar_report("Enl VV10 (RKS)", exc)
    call dev_to_host(h_mat, d_vxc, nao*nao)
    call matrix_report("Vnl VV10 (RKS)", h_mat, nao)
    deallocate(h_c)

    call dev_free(d_vxc)
    call dev_free(d_cocc)

    ! ---- 11. UKS nonlocal (VV10) parameters --------------------------------
    call cuest_check(cuestParametersCreate(CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS, &
                     vv10_uks_par), "ParametersCreate(VV10 UKS)")

    vv10_scale = 1.0d0
    vv10_c     = 0.01d0
    vv10_b     = 6.0d0

    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS, vv10_uks_par, &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS_VV10_SCALE, &
        c_loc(vv10_scale), c_sizeof(vv10_scale)), "Configure(VV10 UKS scale)")
    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS, vv10_uks_par, &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS_VV10_C, &
        c_loc(vv10_c), c_sizeof(vv10_c)), "Configure(VV10 UKS C)")
    call cuest_check(cuestParametersConfigure( &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS, vv10_uks_par, &
        CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS_VV10_B, &
        c_loc(vv10_b), c_sizeof(vv10_b)), "Configure(VV10 UKS b)")

    ! ---- 12. UKS nonlocal energy and potential -----------------------------
    !
    ! A doublet cation: one fewer beta electron than alpha. The UKS nonlocal
    ! potential is a single matrix, not one per spin channel.
    nocc_a = nocc
    nocc_b = nocc - 1
    exc_uks = 0.0d0

    d_vxc_uks = dev_alloc(nao*nao)
    d_cocc_a  = dev_alloc(nocc_a*nao)
    d_cocc_b  = dev_alloc(nocc_b*nao)
    call fill_matrix(d_cocc_a, nocc_a, nao)
    call fill_matrix(d_cocc_b, nocc_b, nao)

    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestNonlocalXCPotentialUKSComputeWorkspaceQuery(handle, &
                     plan, vv10_uks_par, var_buf, d_temp, nocc_a, nocc_b, &
                     d_cocc_a, d_cocc_b, c_loc(exc_uks), d_vxc_uks), &
                     "NonlocalXCPotentialUKSComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestNonlocalXCPotentialUKSCompute(handle, plan, &
                     vv10_uks_par, var_buf, ws_tmp, nocc_a, nocc_b, d_cocc_a, &
                     d_cocc_b, c_loc(exc_uks), d_vxc_uks), &
                     "cuestNonlocalXCPotentialUKSCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_NONLOCALXCPOTENTIALUKSCOMPUTE_PARAMETERS, &
                     vv10_uks_par), "ParametersDestroy(VV10 UKS)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    allocate(h_c(nocc_a*nao))
    call dev_to_host(h_c, d_cocc_a, nocc_a*nao)
    call array_report("CoccA (UKS alpha MO coefficients)", h_c, nocc_a*nao)
    deallocate(h_c)
    allocate(h_c(nocc_b*nao))
    call dev_to_host(h_c, d_cocc_b, nocc_b*nao)
    call array_report("CoccB (UKS beta MO coefficients)", h_c, nocc_b*nao)
    deallocate(h_c)
    call scalar_report("Enl VV10 (UKS)", exc_uks)
    call dev_to_host(h_mat, d_vxc_uks, nao*nao)
    call matrix_report("Vnl VV10 (UKS)", h_mat, nao)

    ! ---- 13. teardown ------------------------------------------------------
    deallocate(h_mat)
    call dev_free(d_vxc_uks)
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

end program nonlocal_xc_potential
