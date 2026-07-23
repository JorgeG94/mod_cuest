! ============================================================================
!  advanced_local_xc_potential.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/4_exchange_correlation/
!    advanced_local_xc_potential/main.c
!
!  The "advanced" XC interface splits the work: cuEST does the rate-limiting
!  density collocation and its adjoint on the GPU, while the functional itself
!  is evaluated on the host. The sample therefore carries its own reference
!  implementations of three exchange functionals -- LDA_X, GGA_X_B86 and
!  MGGA_X_LTA -- plus grid "sanitizers" that zero out points where the
!  synthetic (random) density derivatives would be unphysical.
!
!  Per ansatz (LDA, GGA, meta-GGA), the flow is:
!
!    AO basis -> atom grids -> molecular grid -> XC integral plan (HF, a
!    placeholder, since cuEST evaluates no functional here)
!      -> cuestXCIntegrationWeightCompute  (grid weights, device -> host)
!      -> cuestXCDensityCompute            (rho and derivatives, device -> host)
!      -> HOST: sanitize, evaluate the functional, build the grid potential
!      -> cuestXCPotentialCompute          (grid potential -> Vxc matrix)
!
!  done once restricted (RKS) and once unrestricted (UKS).
!
!  Numerical fidelity notes
!  ------------------------
!  * cbrt() and pow() are bound directly to libm rather than spelled with
!    Fortran operators, so the host arithmetic is bit-identical to the C
!    reference instead of merely equivalent.
!  * C's `!(x >= y)` idiom (a "<" test that also catches NaN) maps directly
!    onto Fortran's `.not. (x >= y)`; IEEE comparison with NaN is false in
!    both languages.
!  * isfinite() maps onto IEEE_IS_FINITE from IEEE_ARITHMETIC.
!  * Grid arrays are declared with lower bound 0 so the index arithmetic is a
!    literal transcription of the C.
!
!  The C sample has no converged SCF to draw orbitals from, so it synthesises
!  the occupied MO coefficient matrices with fill_matrix(): Box-Muller normal
!  deviates from libc rand() after srand(0). This port calls the very same
!  libc srand()/rand() through iso_c_binding, in the same order.
!
!  Difference from the C sample: it computes everything and exits printing only
!  the sanitizer statistics. This port prints a numeric fingerprint of the grid
!  weights, the functional values, the grid potential, the energies and the
!  potential matrices.
!
!  Usage:  ./advanced_local_xc_potential <xyz_file> <gbs_file>
! ============================================================================
program advanced_local_xc_potential
    use, intrinsic :: iso_c_binding
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
    use grid_helper
    implicit none

    !> libc: the pseudo-random generator the C sample fills its synthetic MO
    !  coefficients from, and the two libm routines whose last bit matters.
    interface
        subroutine c_srand(seed) bind(C, name="srand")
            import :: c_int
            integer(c_int), value :: seed
        end subroutine c_srand
        integer(c_int) function c_rand() bind(C, name="rand")
            import :: c_int
        end function c_rand
        real(c_double) function cbrt(x) bind(C, name="cbrt")
            import :: c_double
            real(c_double), value :: x
        end function cbrt
        real(c_double) function c_pow(x, y) bind(C, name="pow")
            import :: c_double
            real(c_double), value :: x, y
        end function c_pow
    end interface

    real(c_double), parameter :: PI = 3.14159265358979323846d0

    !> The Slater exchange constants. In C these are
    !>     const double C_x = 0.75 * cbrt(3.0 / M_PI);
    !>     const double K_x = C_x * cbrt(2.0);
    !> which GCC evaluates at compile time with correctly-rounded arithmetic.
    !> glibc's runtime cbrt() returns a value 1 ulp above the correctly-rounded
    !> one for both 3/pi and 2, so calling cbrt() here would disagree with the C
    !> reference by ~2e-16. Spelling the folded results as literals instead
    !> reproduces the reference bit for bit. (cbrt(4.0), used by
    !> sanitize_grid_rks_gga below, folds to the same double glibc returns, so
    !> that one is left as a call.)
    real(c_double), parameter :: C_X = 0.73855876638202233586d0
    real(c_double), parameter :: K_X = 0.93052573634909996336d0

    ! Sanitizer thresholds, verbatim from the C sample.
    real(c_double), parameter :: SANITIZE_RHO_SAFE  = 1.0d-10
    real(c_double), parameter :: SANITIZE_ZETA_SAFE = 1.0d-8
    real(c_double), parameter :: SANITIZE_XS_SQ_MAX = 1.0d1
    real(c_double), parameter :: SANITIZE_ZETA_MGGA = 1.0d-4

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t), parameter :: NUM_RADIAL  = 75_c_int64_t
    integer(c_int64_t), parameter :: NUM_ANGULAR = 302_c_int64_t

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST advanced local XC potential (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- parse the geometry ------------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    write(*,'(A,I0)') "  atoms    : ", xyz%num_atoms

    ! ---- cuEST handle ------------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- AO shells (shared by all three passes) ----------------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd)
    write(*,'(A,I0)') "  shells   : ", sd%num_shells_total

    ! ---- one pass per ansatz -----------------------------------------------
    call run_ansatz(CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_LDA,     "LDA")
    call run_ansatz(CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_GGA,     "GGA")
    call run_ansatz(CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_METAGGA, "MGGA")

    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)
    call free_ao_shell_data(sd)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    ! ========================================================================
    !  One complete RKS + UKS evaluation for a given ansatz.
    ! ========================================================================
    subroutine run_ansatz(ansatz, aname)
        integer(c_int), intent(in) :: ansatz
        character(*),   intent(in) :: aname

        type(atom_grid_data_t) :: gd
        type(c_ptr) :: basis_par = c_null_ptr, mgrid_par = c_null_ptr
        type(c_ptr) :: plan_par = c_null_ptr
        type(c_ptr) :: wt_par = c_null_ptr, den_par = c_null_ptr, pot_par = c_null_ptr
        type(c_ptr) :: basis = c_null_ptr, mgrid = c_null_ptr, plan = c_null_ptr
        type(c_ptr) :: d_vxc = c_null_ptr, d_cocc = c_null_ptr
        type(c_ptr) :: d_vxc_a = c_null_ptr, d_vxc_b = c_null_ptr
        type(c_ptr) :: d_cocc_a = c_null_ptr, d_cocc_b = c_null_ptr
        type(c_ptr) :: d_weights = c_null_ptr, d_rho = c_null_ptr
        type(c_ptr) :: d_rho_a = c_null_ptr, d_rho_b = c_null_ptr
        type(c_ptr) :: d_vxc_grid = c_null_ptr
        type(c_ptr) :: d_vxc_grid_a = c_null_ptr, d_vxc_grid_b = c_null_ptr

        type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
        type(cuestWorkspace_t) :: ws_basis, ws_grid, ws_plan, ws_tmp

        integer(c_int64_t) :: num_atoms, nao, npoint, nocc, nocc_a, nocc_b
        integer(c_int64_t) :: ncomp
        integer(c_int)     :: ist2
        integer            :: i, p, c

        real(c_double), allocatable :: h_weights(:)
        real(c_double), allocatable :: h_rho_derivs(:), h_rho_derivst(:)
        real(c_double), allocatable :: h_rho_a_derivs(:), h_rho_b_derivs(:)
        real(c_double), allocatable :: h_rho_a_derivst(:), h_rho_b_derivst(:)
        real(c_double), allocatable :: h_vxc_grid(:), h_vxc_grid_a(:), h_vxc_grid_b(:)
        real(c_double), allocatable :: h_rho(:), h_gamma(:), h_tau(:)
        real(c_double), allocatable :: f(:), f_rho(:), f_gamma(:), f_tau(:)
        real(c_double), allocatable :: h_mat(:)

        real(c_double) :: exc, integrated_density
        real(c_double) :: integrated_density_a, integrated_density_b
        real(c_double) :: w, fg_aa, fg_ab, fg_bb
        logical :: nan_found

        num_atoms = xyz%num_atoms

        ! ---- AO basis ------------------------------------------------------
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

        ! ---- atom grids and molecular grid ---------------------------------
        call form_direct_product_atom_grid(handle, xyz, NUM_RADIAL, NUM_ANGULAR, gd)

        call cuest_check(cuestParametersCreate(CUEST_MOLECULARGRID_PARAMETERS, &
                         mgrid_par), "ParametersCreate(molecular grid)")
        call cuest_check(cuestMolecularGridCreateWorkspaceQuery(handle, num_atoms, &
                         gd%grids, c_loc(xyz%xyz_cpu), mgrid_par, d_persist, &
                         d_temp, mgrid), "MolecularGridCreateWorkspaceQuery")
        call ws_alloc(ws_grid, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestMolecularGridCreate(handle, num_atoms, gd%grids, &
                         c_loc(xyz%xyz_cpu), mgrid_par, ws_grid, ws_tmp, mgrid), &
                         "cuestMolecularGridCreate")
        call cuest_check(cuestParametersDestroy(CUEST_MOLECULARGRID_PARAMETERS, &
                         mgrid_par), "ParametersDestroy(molecular grid)")
        call ws_free(ws_tmp)
        call free_atom_grid_data(gd)

        ! ---- XC integral plan ----------------------------------------------
        ! cuEST evaluates no functional here, so the functional argument to
        ! cuestXCIntPlanCreate is an arbitrary placeholder. Note the C sample
        ! passes PBE to the workspace query and HF to the create call; that
        ! asymmetry is upstream's and is reproduced deliberately.
        call cuest_check(cuestParametersCreate(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                         "ParametersCreate(XC plan)")
        call cuest_check(cuestXCIntPlanCreateWorkspaceQuery(handle, basis, mgrid, &
                         CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_PBE, plan_par, &
                         d_persist, d_temp, plan), "XCIntPlanCreateWorkspaceQuery")
        call ws_alloc(ws_plan, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCIntPlanCreate(handle, basis, mgrid, &
                         CUEST_XCINTPLAN_PARAMETERS_FUNCTIONAL_HF, plan_par, &
                         ws_plan, ws_tmp, plan), "cuestXCIntPlanCreate")
        call cuest_check(cuestParametersDestroy(CUEST_XCINTPLAN_PARAMETERS, plan_par), &
                         "ParametersDestroy(XC plan)")
        call ws_free(ws_tmp)

        ! ---- dimensions ----------------------------------------------------
        nao = 0
        call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                         CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
        npoint = 0
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, mgrid, &
                         CUEST_MOLECULARGRID_NUM_POINT, npoint), "query NUM_POINT")

        var_buf%hostBufferSizeInBytes   = 0_c_size_t
        var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

        ! nocc for a neutral molecule; charges are stored as -Z
        nocc = 0
        do i = 1, int(num_atoms)
            nocc = nocc + int(abs(xyz%charges_cpu(i)), c_int64_t)
        end do
        nocc = nocc / 2

        select case (ansatz)
        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_LDA)
            ncomp = 1
        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_GGA)
            ncomp = 4
        case default
            ncomp = 5
        end select

        allocate(h_mat(nao*nao))

        ! ====================================================================
        !  RKS
        ! ====================================================================
        d_vxc  = dev_alloc(nao*nao)
        d_cocc = dev_alloc(nocc*nao)
        call fill_matrix(d_cocc, nocc, nao)

        ! ---- integration weights, device -> host ---------------------------
        d_weights = dev_alloc(npoint)
        call cuest_check(cuestParametersCreate(CUEST_XCINTEGRATIONWEIGHTCOMPUTE_PARAMETERS, &
                         wt_par), "ParametersCreate(weights)")
        call cuest_check(cuestXCIntegrationWeightComputeWorkspaceQuery(handle, plan, &
                         CUEST_XCINTEGRATIONWEIGHT_PARAMETERS_WEIGHTTYPE_TOTAL, &
                         wt_par, d_temp, d_weights), &
                         "XCIntegrationWeightComputeWorkspaceQuery")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCIntegrationWeightCompute(handle, plan, &
                         CUEST_XCINTEGRATIONWEIGHT_PARAMETERS_WEIGHTTYPE_TOTAL, &
                         wt_par, ws_tmp, d_weights), "cuestXCIntegrationWeightCompute")
        call cuest_check(cuestParametersDestroy(CUEST_XCINTEGRATIONWEIGHTCOMPUTE_PARAMETERS, &
                         wt_par), "ParametersDestroy(weights)")
        call ws_free(ws_tmp)

        allocate(h_weights(0:npoint-1))
        call dev_to_host(h_weights, d_weights, npoint)
        call dev_free(d_weights)

        ! ---- grid density and derivatives, device -> host ------------------
        call cuest_check(cuestParametersCreate(CUEST_XCDENSITYCOMPUTE_PARAMETERS, &
                         den_par), "ParametersCreate(density)")
        d_rho = dev_alloc(npoint*ncomp)
        call cuest_check(cuestXCDensityComputeWorkspaceQuery(handle, plan, ansatz, &
                         den_par, var_buf, d_temp, nocc, d_cocc, d_rho), &
                         "XCDensityComputeWorkspaceQuery")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCDensityCompute(handle, plan, ansatz, den_par, &
                         var_buf, ws_tmp, nocc, d_cocc, d_rho), &
                         "cuestXCDensityCompute")
        call ws_free(ws_tmp)
        call cuest_check(cuestParametersDestroy(CUEST_XCDENSITYCOMPUTE_PARAMETERS, &
                         den_par), "ParametersDestroy(density)")

        allocate(h_rho_derivs(0:npoint*ncomp-1), h_rho_derivst(0:npoint*ncomp-1))
        call dev_to_host(h_rho_derivs, d_rho, npoint*ncomp)
        call dev_free(d_rho)
        do p = 0, int(npoint)-1
            do c = 0, int(ncomp)-1
                h_rho_derivst(c*npoint + p) = h_rho_derivs(p*ncomp + c)
            end do
        end do
        deallocate(h_rho_derivs)

        allocate(h_vxc_grid(0:npoint*ncomp-1))
        allocate(f(0:npoint-1), f_rho(0:npoint-1))

        select case (ansatz)
        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_LDA)
            allocate(h_rho(0:npoint-1))
            do p = 0, int(npoint)-1
                h_rho(p) = 2.0d0 * h_rho_derivst(p)
            end do
            call sanitize_grid_rks_lda(npoint, h_rho)
            call my_xc_lda_exc_vxc(npoint, h_rho, f, f_rho, 0)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))     nan_found = .true.
                if (.not. ieee_is_finite(f_rho(i))) nan_found = .true.
                if (nan_found) then
                    f(i)     = 0.0d0
                    f_rho(i) = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                h_vxc_grid(p) = h_weights(p) * f_rho(p)
            end do
            deallocate(h_rho)

        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_GGA)
            allocate(h_rho(0:npoint-1), h_gamma(0:npoint-1))
            do p = 0, int(npoint)-1
                h_rho(p) = 2.0d0 * h_rho_derivst(p)
                h_gamma(p) = 4.0d0 * (h_rho_derivst(npoint + p)**2 &
                                    + h_rho_derivst(2*npoint + p)**2 &
                                    + h_rho_derivst(3*npoint + p)**2)
            end do
            call sanitize_grid_rks_gga(npoint, h_rho, h_gamma)
            allocate(f_gamma(0:npoint-1))
            call my_xc_gga_exc_vxc(npoint, h_rho, h_gamma, f, f_rho, f_gamma, 0)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))       nan_found = .true.
                if (.not. ieee_is_finite(f_rho(i)))   nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(i))) nan_found = .true.
                if (nan_found) then
                    f(i)       = 0.0d0
                    f_rho(i)   = 0.0d0
                    f_gamma(i) = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                w = h_weights(p)
                h_vxc_grid(4*p + 0) = w * f_rho(p)
                h_vxc_grid(4*p + 1) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(npoint + p)
                h_vxc_grid(4*p + 2) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(2*npoint + p)
                h_vxc_grid(4*p + 3) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(3*npoint + p)
            end do
            deallocate(h_rho, h_gamma, f_gamma)

        case default   ! meta-GGA
            allocate(h_rho(0:npoint-1), h_gamma(0:npoint-1), h_tau(0:npoint-1))
            do p = 0, int(npoint)-1
                h_rho(p) = 2.0d0 * h_rho_derivst(p)
                h_gamma(p) = 4.0d0 * (h_rho_derivst(npoint + p)**2 &
                                    + h_rho_derivst(2*npoint + p)**2 &
                                    + h_rho_derivst(3*npoint + p)**2)
                h_tau(p) = 2.0d0 * h_rho_derivst(4*npoint + p)
            end do
            ! MGGA_X_LTA has no sigma dependence and the inner kernel already
            ! guards rho > 0 and tau > 0, so no grid sanitization is needed.
            allocate(f_gamma(0:npoint-1), f_tau(0:npoint-1))
            call my_xc_mgga_exc_vxc(npoint, h_rho, h_gamma, h_tau, f, f_rho, &
                                    f_gamma, f_tau, 0)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))       nan_found = .true.
                if (.not. ieee_is_finite(f_rho(i)))   nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(i))) nan_found = .true.
                if (.not. ieee_is_finite(f_tau(i)))   nan_found = .true.
                if (nan_found) then
                    f(i)       = 0.0d0
                    f_rho(i)   = 0.0d0
                    f_gamma(i) = 0.0d0
                    f_tau(i)   = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                w = h_weights(p)
                h_vxc_grid(5*p + 0) = w * f_rho(p)
                h_vxc_grid(5*p + 1) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(npoint + p)
                h_vxc_grid(5*p + 2) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(2*npoint + p)
                h_vxc_grid(5*p + 3) = 4.0d0 * w * f_gamma(p) * h_rho_derivst(3*npoint + p)
                h_vxc_grid(5*p + 4) = w * f_tau(p)
            end do
            deallocate(h_rho, h_gamma, h_tau, f_gamma, f_tau)
        end select

        ! ---- XC energy and integrated density ------------------------------
        exc = 0.0d0
        integrated_density = 0.0d0
        do p = 0, int(npoint)-1
            exc = exc + 2.0d0 * h_weights(p) * f(p) * h_rho_derivst(p)
            integrated_density = integrated_density &
                               + 2.0d0 * h_weights(p) * h_rho_derivst(p)
        end do

        write(*,'(A)') ""
        call array_report(aname//" RKS grid weights", h_weights, npoint)
        call array_report(aname//" RKS f", f, npoint)
        call array_report(aname//" RKS Vxc grid", h_vxc_grid, npoint*ncomp)
        call scalar_report(aname//" RKS Exc", exc)
        call scalar_report(aname//" RKS integrated density", integrated_density)

        deallocate(f, f_rho, h_weights, h_rho_derivst)

        ! ---- grid potential -> Vxc matrix ----------------------------------
        d_vxc_grid = dev_alloc(npoint*ncomp)
        call host_to_dev(d_vxc_grid, h_vxc_grid, npoint*ncomp)
        deallocate(h_vxc_grid)

        call cuest_check(cuestParametersCreate(CUEST_XCPOTENTIALCOMPUTE_PARAMETERS, &
                         pot_par), "ParametersCreate(potential)")
        call cuest_check(cuestXCPotentialComputeWorkspaceQuery(handle, plan, ansatz, &
                         pot_par, var_buf, d_temp, d_vxc_grid, d_vxc), &
                         "XCPotentialComputeWorkspaceQuery")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCPotentialCompute(handle, plan, ansatz, pot_par, &
                         var_buf, ws_tmp, d_vxc_grid, d_vxc), &
                         "cuestXCPotentialCompute")
        call ws_free(ws_tmp)
        call cuest_check(cuestParametersDestroy(CUEST_XCPOTENTIALCOMPUTE_PARAMETERS, &
                         pot_par), "ParametersDestroy(potential)")
        call dev_free(d_vxc_grid)

        call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")
        call dev_to_host(h_mat, d_vxc, nao*nao)
        call matrix_report(aname//" RKS Vxc", h_mat, nao)

        call dev_free(d_vxc)
        call dev_free(d_cocc)

        ! ====================================================================
        !  UKS -- a doublet cation
        ! ====================================================================
        nocc_a = nocc
        nocc_b = nocc - 1

        d_vxc_a  = dev_alloc(nao*nao)
        d_vxc_b  = dev_alloc(nao*nao)
        d_cocc_a = dev_alloc(nocc_a*nao)
        d_cocc_b = dev_alloc(nocc_b*nao)
        call fill_matrix(d_cocc_a, nocc_a, nao)
        call fill_matrix(d_cocc_b, nocc_b, nao)

        ! ---- integration weights again -------------------------------------
        d_weights = dev_alloc(npoint)
        call cuest_check(cuestParametersCreate(CUEST_XCINTEGRATIONWEIGHTCOMPUTE_PARAMETERS, &
                         wt_par), "ParametersCreate(weights UKS)")
        call cuest_check(cuestXCIntegrationWeightComputeWorkspaceQuery(handle, plan, &
                         CUEST_XCINTEGRATIONWEIGHT_PARAMETERS_WEIGHTTYPE_TOTAL, &
                         wt_par, d_temp, d_weights), &
                         "XCIntegrationWeightComputeWorkspaceQuery(UKS)")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCIntegrationWeightCompute(handle, plan, &
                         CUEST_XCINTEGRATIONWEIGHT_PARAMETERS_WEIGHTTYPE_TOTAL, &
                         wt_par, ws_tmp, d_weights), &
                         "cuestXCIntegrationWeightCompute(UKS)")
        call cuest_check(cuestParametersDestroy(CUEST_XCINTEGRATIONWEIGHTCOMPUTE_PARAMETERS, &
                         wt_par), "ParametersDestroy(weights UKS)")
        call ws_free(ws_tmp)
        allocate(h_weights(0:npoint-1))
        call dev_to_host(h_weights, d_weights, npoint)
        call dev_free(d_weights)

        ! ---- per-spin grid densities ---------------------------------------
        call cuest_check(cuestParametersCreate(CUEST_XCDENSITYCOMPUTE_PARAMETERS, &
                         den_par), "ParametersCreate(density UKS)")
        d_rho_a = dev_alloc(npoint*ncomp)
        d_rho_b = dev_alloc(npoint*ncomp)

        call cuest_check(cuestXCDensityComputeWorkspaceQuery(handle, plan, ansatz, &
                         den_par, var_buf, d_temp, nocc_a, d_cocc_a, d_rho_a), &
                         "XCDensityComputeWorkspaceQuery(alpha)")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCDensityCompute(handle, plan, ansatz, den_par, &
                         var_buf, ws_tmp, nocc_a, d_cocc_a, d_rho_a), &
                         "cuestXCDensityCompute(alpha)")
        call ws_free(ws_tmp)

        call cuest_check(cuestXCDensityComputeWorkspaceQuery(handle, plan, ansatz, &
                         den_par, var_buf, d_temp, nocc_b, d_cocc_b, d_rho_b), &
                         "XCDensityComputeWorkspaceQuery(beta)")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCDensityCompute(handle, plan, ansatz, den_par, &
                         var_buf, ws_tmp, nocc_b, d_cocc_b, d_rho_b), &
                         "cuestXCDensityCompute(beta)")
        call ws_free(ws_tmp)
        call cuest_check(cuestParametersDestroy(CUEST_XCDENSITYCOMPUTE_PARAMETERS, &
                         den_par), "ParametersDestroy(density UKS)")

        allocate(h_rho_a_derivs(0:npoint*ncomp-1), h_rho_b_derivs(0:npoint*ncomp-1))
        call dev_to_host(h_rho_a_derivs, d_rho_a, npoint*ncomp)
        call dev_to_host(h_rho_b_derivs, d_rho_b, npoint*ncomp)
        call dev_free(d_rho_a)
        call dev_free(d_rho_b)

        allocate(h_rho_a_derivst(0:npoint*ncomp-1), h_rho_b_derivst(0:npoint*ncomp-1))
        do p = 0, int(npoint)-1
            do c = 0, int(ncomp)-1
                h_rho_a_derivst(c*npoint + p) = h_rho_a_derivs(p*ncomp + c)
                h_rho_b_derivst(c*npoint + p) = h_rho_b_derivs(p*ncomp + c)
            end do
        end do
        deallocate(h_rho_a_derivs, h_rho_b_derivs)

        allocate(h_vxc_grid_a(0:npoint*ncomp-1), h_vxc_grid_b(0:npoint*ncomp-1))
        allocate(f(0:npoint-1), f_rho(0:npoint*2-1))

        select case (ansatz)
        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_LDA)
            allocate(h_rho(0:npoint*2-1))
            do p = 0, int(npoint)-1
                h_rho(2*p + 0) = h_rho_a_derivst(p)
                h_rho(2*p + 1) = h_rho_b_derivst(p)
            end do
            call sanitize_grid_uks_lda(npoint, h_rho)
            call my_xc_lda_exc_vxc(npoint, h_rho, f, f_rho, 1)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))           nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 0))) nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 1))) nan_found = .true.
                if (nan_found) then
                    f(i)           = 0.0d0
                    f_rho(2*i + 0) = 0.0d0
                    f_rho(2*i + 1) = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                w = h_weights(p)
                h_vxc_grid_a(p) = w * f_rho(2*p + 0)
                h_vxc_grid_b(p) = w * f_rho(2*p + 1)
            end do
            deallocate(h_rho)

        case (CUEST_XCADVANCED_PARAMETERS_APPROXIMATION_GGA)
            allocate(h_rho(0:npoint*2-1), h_gamma(0:npoint*3-1))
            do p = 0, int(npoint)-1
                h_rho(2*p + 0) = h_rho_a_derivst(p)
                h_rho(2*p + 1) = h_rho_b_derivst(p)
                h_gamma(3*p + 0) = h_rho_a_derivst(npoint + p) * h_rho_a_derivst(npoint + p)   &
                                 + h_rho_a_derivst(2*npoint + p) * h_rho_a_derivst(2*npoint + p) &
                                 + h_rho_a_derivst(3*npoint + p) * h_rho_a_derivst(3*npoint + p)
                h_gamma(3*p + 1) = h_rho_a_derivst(npoint + p) * h_rho_b_derivst(npoint + p)   &
                                 + h_rho_a_derivst(2*npoint + p) * h_rho_b_derivst(2*npoint + p) &
                                 + h_rho_a_derivst(3*npoint + p) * h_rho_b_derivst(3*npoint + p)
                h_gamma(3*p + 2) = h_rho_b_derivst(npoint + p) * h_rho_b_derivst(npoint + p)   &
                                 + h_rho_b_derivst(2*npoint + p) * h_rho_b_derivst(2*npoint + p) &
                                 + h_rho_b_derivst(3*npoint + p) * h_rho_b_derivst(3*npoint + p)
            end do
            call sanitize_grid_uks_gga(npoint, h_rho, h_gamma)
            allocate(f_gamma(0:npoint*3-1))
            call my_xc_gga_exc_vxc(npoint, h_rho, h_gamma, f, f_rho, f_gamma, 1)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))             nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 0)))   nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 1)))   nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 0))) nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 1))) nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 2))) nan_found = .true.
                if (nan_found) then
                    f(i)             = 0.0d0
                    f_rho(2*i + 0)   = 0.0d0
                    f_rho(2*i + 1)   = 0.0d0
                    f_gamma(3*i + 0) = 0.0d0
                    f_gamma(3*i + 1) = 0.0d0
                    f_gamma(3*i + 2) = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                w = h_weights(p)
                fg_aa = f_gamma(3*p + 0)
                fg_ab = f_gamma(3*p + 1)
                fg_bb = f_gamma(3*p + 2)
                h_vxc_grid_a(4*p + 0) = w * f_rho(2*p + 0)
                h_vxc_grid_a(4*p + 1) = w * (2.0d0*fg_aa*h_rho_a_derivst(npoint + p) &
                                           + fg_ab*h_rho_b_derivst(npoint + p))
                h_vxc_grid_a(4*p + 2) = w * (2.0d0*fg_aa*h_rho_a_derivst(2*npoint + p) &
                                           + fg_ab*h_rho_b_derivst(2*npoint + p))
                h_vxc_grid_a(4*p + 3) = w * (2.0d0*fg_aa*h_rho_a_derivst(3*npoint + p) &
                                           + fg_ab*h_rho_b_derivst(3*npoint + p))
                h_vxc_grid_b(4*p + 0) = w * f_rho(2*p + 1)
                h_vxc_grid_b(4*p + 1) = w * (2.0d0*fg_bb*h_rho_b_derivst(npoint + p) &
                                           + fg_ab*h_rho_a_derivst(npoint + p))
                h_vxc_grid_b(4*p + 2) = w * (2.0d0*fg_bb*h_rho_b_derivst(2*npoint + p) &
                                           + fg_ab*h_rho_a_derivst(2*npoint + p))
                h_vxc_grid_b(4*p + 3) = w * (2.0d0*fg_bb*h_rho_b_derivst(3*npoint + p) &
                                           + fg_ab*h_rho_a_derivst(3*npoint + p))
            end do
            deallocate(h_rho, h_gamma, f_gamma)

        case default   ! meta-GGA
            allocate(h_rho(0:npoint*2-1), h_gamma(0:npoint*3-1), h_tau(0:npoint*2-1))
            do p = 0, int(npoint)-1
                h_rho(2*p + 0) = h_rho_a_derivst(p)
                h_rho(2*p + 1) = h_rho_b_derivst(p)
                h_gamma(3*p + 0) = h_rho_a_derivst(npoint + p) * h_rho_a_derivst(npoint + p)   &
                                 + h_rho_a_derivst(2*npoint + p) * h_rho_a_derivst(2*npoint + p) &
                                 + h_rho_a_derivst(3*npoint + p) * h_rho_a_derivst(3*npoint + p)
                h_gamma(3*p + 1) = h_rho_a_derivst(npoint + p) * h_rho_b_derivst(npoint + p)   &
                                 + h_rho_a_derivst(2*npoint + p) * h_rho_b_derivst(2*npoint + p) &
                                 + h_rho_a_derivst(3*npoint + p) * h_rho_b_derivst(3*npoint + p)
                h_gamma(3*p + 2) = h_rho_b_derivst(npoint + p) * h_rho_b_derivst(npoint + p)   &
                                 + h_rho_b_derivst(2*npoint + p) * h_rho_b_derivst(2*npoint + p) &
                                 + h_rho_b_derivst(3*npoint + p) * h_rho_b_derivst(3*npoint + p)
                h_tau(2*p + 0) = h_rho_a_derivst(4*npoint + p)
                h_tau(2*p + 1) = h_rho_b_derivst(4*npoint + p)
            end do
            call sanitize_grid_uks_mgga(npoint, h_rho, h_tau)
            allocate(f_gamma(0:npoint*3-1), f_tau(0:npoint*2-1))
            call my_xc_mgga_exc_vxc(npoint, h_rho, h_gamma, h_tau, f, f_rho, &
                                    f_gamma, f_tau, 1)
            do i = 0, int(npoint)-1
                nan_found = .false.
                if (.not. ieee_is_finite(f(i)))             nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 0)))   nan_found = .true.
                if (.not. ieee_is_finite(f_rho(2*i + 1)))   nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 0))) nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 1))) nan_found = .true.
                if (.not. ieee_is_finite(f_gamma(3*i + 2))) nan_found = .true.
                if (.not. ieee_is_finite(f_tau(2*i + 0)))   nan_found = .true.
                if (.not. ieee_is_finite(f_tau(2*i + 1)))   nan_found = .true.
                if (nan_found) then
                    f(i)             = 0.0d0
                    f_rho(2*i + 0)   = 0.0d0
                    f_rho(2*i + 1)   = 0.0d0
                    f_gamma(3*i + 0) = 0.0d0
                    f_gamma(3*i + 1) = 0.0d0
                    f_gamma(3*i + 2) = 0.0d0
                    f_tau(2*i + 0)   = 0.0d0
                    f_tau(2*i + 1)   = 0.0d0
                end if
            end do
            do p = 0, int(npoint)-1
                w = h_weights(p)
                fg_aa = f_gamma(3*p + 0)
                fg_ab = f_gamma(3*p + 1)
                fg_bb = f_gamma(3*p + 2)
                h_vxc_grid_a(5*p + 0) = w * f_rho(2*p + 0)
                h_vxc_grid_a(5*p + 1) = w * (2.0d0*fg_aa*h_rho_a_derivst(npoint + p) &
                                           + fg_ab*h_rho_b_derivst(npoint + p))
                h_vxc_grid_a(5*p + 2) = w * (2.0d0*fg_aa*h_rho_a_derivst(2*npoint + p) &
                                           + fg_ab*h_rho_b_derivst(2*npoint + p))
                h_vxc_grid_a(5*p + 3) = w * (2.0d0*fg_aa*h_rho_a_derivst(3*npoint + p) &
                                           + fg_ab*h_rho_b_derivst(3*npoint + p))
                h_vxc_grid_a(5*p + 4) = w * f_tau(2*p + 0)
                h_vxc_grid_b(5*p + 0) = w * f_rho(2*p + 1)
                h_vxc_grid_b(5*p + 1) = w * (2.0d0*fg_bb*h_rho_b_derivst(npoint + p) &
                                           + fg_ab*h_rho_a_derivst(npoint + p))
                h_vxc_grid_b(5*p + 2) = w * (2.0d0*fg_bb*h_rho_b_derivst(2*npoint + p) &
                                           + fg_ab*h_rho_a_derivst(2*npoint + p))
                h_vxc_grid_b(5*p + 3) = w * (2.0d0*fg_bb*h_rho_b_derivst(3*npoint + p) &
                                           + fg_ab*h_rho_a_derivst(3*npoint + p))
                h_vxc_grid_b(5*p + 4) = w * f_tau(2*p + 1)
            end do
            deallocate(h_rho, h_gamma, h_tau, f_gamma, f_tau)
        end select

        ! ---- XC energy and integrated densities ----------------------------
        exc = 0.0d0
        integrated_density_a = 0.0d0
        integrated_density_b = 0.0d0
        do p = 0, int(npoint)-1
            exc = exc + h_weights(p) * f(p) &
                      * (h_rho_a_derivst(p) + h_rho_b_derivst(p))
            integrated_density_a = integrated_density_a + h_weights(p)*h_rho_a_derivst(p)
            integrated_density_b = integrated_density_b + h_weights(p)*h_rho_b_derivst(p)
        end do

        call array_report(aname//" UKS f", f, npoint)
        call array_report(aname//" UKS Vxc grid alpha", h_vxc_grid_a, npoint*ncomp)
        call array_report(aname//" UKS Vxc grid beta", h_vxc_grid_b, npoint*ncomp)
        call scalar_report(aname//" UKS Exc", exc)
        call scalar_report(aname//" UKS integrated density alpha", integrated_density_a)
        call scalar_report(aname//" UKS integrated density beta", integrated_density_b)

        deallocate(f, f_rho, h_weights, h_rho_a_derivst, h_rho_b_derivst)

        ! ---- grid potentials -> Vxc matrices -------------------------------
        d_vxc_grid_a = dev_alloc(npoint*ncomp)
        call host_to_dev(d_vxc_grid_a, h_vxc_grid_a, npoint*ncomp)
        deallocate(h_vxc_grid_a)
        d_vxc_grid_b = dev_alloc(npoint*ncomp)
        call host_to_dev(d_vxc_grid_b, h_vxc_grid_b, npoint*ncomp)
        deallocate(h_vxc_grid_b)

        call cuest_check(cuestParametersCreate(CUEST_XCPOTENTIALCOMPUTE_PARAMETERS, &
                         pot_par), "ParametersCreate(potential UKS)")
        call cuest_check(cuestXCPotentialComputeWorkspaceQuery(handle, plan, ansatz, &
                         pot_par, var_buf, d_temp, d_vxc_grid_a, d_vxc_a), &
                         "XCPotentialComputeWorkspaceQuery(alpha)")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCPotentialCompute(handle, plan, ansatz, pot_par, &
                         var_buf, ws_tmp, d_vxc_grid_a, d_vxc_a), &
                         "cuestXCPotentialCompute(alpha)")
        call ws_free(ws_tmp)
        call cuest_check(cuestXCPotentialComputeWorkspaceQuery(handle, plan, ansatz, &
                         pot_par, var_buf, d_temp, d_vxc_grid_b, d_vxc_b), &
                         "XCPotentialComputeWorkspaceQuery(beta)")
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestXCPotentialCompute(handle, plan, ansatz, pot_par, &
                         var_buf, ws_tmp, d_vxc_grid_b, d_vxc_b), &
                         "cuestXCPotentialCompute(beta)")
        call ws_free(ws_tmp)
        call cuest_check(cuestParametersDestroy(CUEST_XCPOTENTIALCOMPUTE_PARAMETERS, &
                         pot_par), "ParametersDestroy(potential UKS)")

        call dev_free(d_vxc_grid_a)
        call dev_free(d_vxc_grid_b)

        call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")
        call dev_to_host(h_mat, d_vxc_a, nao*nao)
        call matrix_report(aname//" UKS Vxc alpha", h_mat, nao)
        call dev_to_host(h_mat, d_vxc_b, nao*nao)
        call matrix_report(aname//" UKS Vxc beta", h_mat, nao)

        call dev_free(d_vxc_a)
        call dev_free(d_vxc_b)
        call dev_free(d_cocc_a)
        call dev_free(d_cocc_b)

        ! ---- teardown ------------------------------------------------------
        deallocate(h_mat)
        ist2 = cuestXCIntPlanDestroy(plan)
        call ws_free(ws_plan)
        ist2 = cuestMolecularGridDestroy(mgrid)
        call ws_free(ws_grid)
        ist2 = cuestAOBasisDestroy(basis)
        call ws_free(ws_basis)
    end subroutine run_ansatz

    ! ========================================================================
    !  Host-side functionals -- transcriptions of the C sample's reference
    !  implementations of libxc's LDA_X, GGA_X_B86 and MGGA_X_LTA.
    ! ========================================================================

    !> Simple reference implementation of libxc's LDA_X exchange functional.
    subroutine my_xc_lda_exc_vxc(npoints, p_rho, p_f, p_f_rho, is_spin_polarized)
        integer(c_int64_t), intent(in)  :: npoints
        real(c_double),     intent(in)  :: p_rho(0:)
        real(c_double),     intent(out) :: p_f(0:), p_f_rho(0:)
        integer,            intent(in)  :: is_spin_polarized
        real(c_double) :: rho, rho_13, eps_x
        real(c_double) :: rho_a, rho_b, rho_total
        real(c_double) :: rho_a_13, rho_a_43, rho_b_13, rho_b_43
        real(c_double), parameter :: RHO_THRESHOLD = 1.0d-15
        integer :: i

        if (is_spin_polarized == 0) then
            do i = 0, int(npoints)-1
                rho = p_rho(i)
                if (rho < RHO_THRESHOLD) then
                    p_f(i)     = 0.0d0
                    p_f_rho(i) = 0.0d0
                    cycle
                end if
                rho_13 = cbrt(rho)
                eps_x  = -C_X * rho_13
                p_f(i)     = eps_x
                p_f_rho(i) = (4.0d0 / 3.0d0) * eps_x
            end do
        else
            do i = 0, int(npoints)-1
                rho_a = p_rho(2*i + 0)
                rho_b = p_rho(2*i + 1)
                rho_total = rho_a + rho_b
                if (rho_total < RHO_THRESHOLD) then
                    p_f(i)           = 0.0d0
                    p_f_rho(2*i + 0) = 0.0d0
                    p_f_rho(2*i + 1) = 0.0d0
                    cycle
                end if
                rho_a_13 = cbrt(rho_a)
                rho_a_43 = rho_a * rho_a_13
                rho_b_13 = cbrt(rho_b)
                rho_b_43 = rho_b * rho_b_13
                p_f(i)           = -K_X * (rho_a_43 + rho_b_43) / rho_total
                p_f_rho(2*i + 0) = -(4.0d0 / 3.0d0) * K_X * rho_a_13
                p_f_rho(2*i + 1) = -(4.0d0 / 3.0d0) * K_X * rho_b_13
            end do
        end if
    end subroutine my_xc_lda_exc_vxc

    !> One spin channel of libxc's GGA_X_B86 exchange functional.
    subroutine b86_eval_one_channel(rho_s, gamma_s, f_per_vol, df_drho_s, df_dgamma_s)
        real(c_double), intent(in)  :: rho_s, gamma_s
        real(c_double), intent(out) :: f_per_vol, df_drho_s, df_dgamma_s
        real(c_double), parameter :: BETA = 0.0036d0
        real(c_double), parameter :: GAMMA = 0.004d0
        real(c_double), parameter :: RHO_THRESHOLD = 1.0d-15
        real(c_double) :: rho_13, rho_43, rho_83, x_sq, d, d2, h

        if (rho_s < RHO_THRESHOLD) then
            f_per_vol   = 0.0d0
            df_drho_s   = 0.0d0
            df_dgamma_s = 0.0d0
            return
        end if

        rho_13 = cbrt(rho_s)
        rho_43 = rho_s * rho_13
        rho_83 = rho_43 * rho_43

        x_sq = gamma_s / rho_83
        d    = 1.0d0 + GAMMA * x_sq
        d2   = d * d
        h    = x_sq / d

        f_per_vol   = -rho_43 * (K_X + BETA * h)
        df_drho_s   = -(4.0d0 / 3.0d0) * rho_13 * (K_X + BETA * h) &
                    + (8.0d0 / 3.0d0) * BETA * rho_13 * x_sq / d2
        df_dgamma_s = -BETA / (rho_43 * d2)
    end subroutine b86_eval_one_channel

    subroutine my_xc_gga_exc_vxc(npoints, p_rho, p_gamma, p_f, p_f_rho, &
                                 p_f_gamma, is_spin_polarized)
        integer(c_int64_t), intent(in)  :: npoints
        real(c_double),     intent(in)  :: p_rho(0:), p_gamma(0:)
        real(c_double),     intent(out) :: p_f(0:), p_f_rho(0:), p_f_gamma(0:)
        integer,            intent(in)  :: is_spin_polarized
        real(c_double), parameter :: RHO_THRESHOLD = 1.0d-15
        real(c_double) :: rho, rho_s, gamma_s, f_s, df_drho_s, df_dgamma_s
        real(c_double) :: f_total_per_vol
        real(c_double) :: rho_a, rho_b, rho_total, gamma_aa, gamma_bb
        real(c_double) :: f_a, df_drho_a, df_dgamma_a
        real(c_double) :: f_b, df_drho_b, df_dgamma_b
        integer :: i

        if (is_spin_polarized == 0) then
            do i = 0, int(npoints)-1
                rho = p_rho(i)
                if (rho < RHO_THRESHOLD) then
                    p_f(i)       = 0.0d0
                    p_f_rho(i)   = 0.0d0
                    p_f_gamma(i) = 0.0d0
                    cycle
                end if
                rho_s   = 0.5d0  * rho
                gamma_s = 0.25d0 * p_gamma(i)
                call b86_eval_one_channel(rho_s, gamma_s, f_s, df_drho_s, df_dgamma_s)
                f_total_per_vol = 2.0d0 * f_s
                p_f(i)       = f_total_per_vol / rho
                p_f_rho(i)   = df_drho_s
                p_f_gamma(i) = 0.5d0 * df_dgamma_s
            end do
        else
            do i = 0, int(npoints)-1
                rho_a    = p_rho(2*i + 0)
                rho_b    = p_rho(2*i + 1)
                gamma_aa = p_gamma(3*i + 0)
                ! gamma_ab is unused -- exchange has no cross-spin term.
                gamma_bb = p_gamma(3*i + 2)
                rho_total = rho_a + rho_b
                if (rho_total < RHO_THRESHOLD) then
                    p_f(i)             = 0.0d0
                    p_f_rho(2*i + 0)   = 0.0d0
                    p_f_rho(2*i + 1)   = 0.0d0
                    p_f_gamma(3*i + 0) = 0.0d0
                    p_f_gamma(3*i + 1) = 0.0d0
                    p_f_gamma(3*i + 2) = 0.0d0
                    cycle
                end if
                call b86_eval_one_channel(rho_a, gamma_aa, f_a, df_drho_a, df_dgamma_a)
                call b86_eval_one_channel(rho_b, gamma_bb, f_b, df_drho_b, df_dgamma_b)
                p_f(i)             = (f_a + f_b) / rho_total
                p_f_rho(2*i + 0)   = df_drho_a
                p_f_rho(2*i + 1)   = df_drho_b
                p_f_gamma(3*i + 0) = df_dgamma_a
                p_f_gamma(3*i + 1) = 0.0d0
                p_f_gamma(3*i + 2) = df_dgamma_b
            end do
        end if
    end subroutine my_xc_gga_exc_vxc

    !> One spin channel of libxc's MGGA_X_LTA exchange functional.
    subroutine lta_eval_one_channel(rho_in, tau_in, f_per_vol, df_drho_s, df_dtau_s)
        real(c_double), intent(in)  :: rho_in, tau_in
        real(c_double), intent(out) :: f_per_vol, df_drho_s, df_dtau_s
        ! (3/8)*(3/pi)^(1/3)*4^(2/3)
        real(c_double), parameter :: X_FACTOR_C = 0.9305257363491000250020102180716672510262d0
        ! (3/10)*(6 pi^2)^(2/3) = tau_unif,sigma / rho_sigma^(5/3)
        real(c_double), parameter :: K_FACTOR_C = 4.557799872345597137288163759599305358515d0
        real(c_double), parameter :: RHO_THRESHOLD = 1.0d-15
        real(c_double), parameter :: TAU_THRESHOLD = 1.0d-20
        real(c_double) :: lta_c, rho_s, tau_s, rho_13, rho_43, rho_53, a, f_x

        lta_c = 1.0d0 / K_FACTOR_C

        rho_s = rho_in
        tau_s = tau_in
        if (rho_s < RHO_THRESHOLD) rho_s = RHO_THRESHOLD
        if (tau_s < TAU_THRESHOLD) tau_s = TAU_THRESHOLD

        rho_13 = cbrt(rho_s)
        rho_43 = rho_s * rho_13
        rho_53 = rho_43 * rho_13

        a   = lta_c * tau_s / rho_53
        f_x = c_pow(a, 0.8d0)

        f_per_vol = -X_FACTOR_C * rho_43 * f_x
        df_drho_s = 0.0d0
        df_dtau_s = -0.8d0 * X_FACTOR_C * rho_43 * f_x / tau_s
    end subroutine lta_eval_one_channel

    subroutine my_xc_mgga_exc_vxc(npoints, p_rho, p_gamma, p_tau, p_f, p_f_rho, &
                                  p_f_gamma, p_f_tau, is_spin_polarized)
        integer(c_int64_t), intent(in)  :: npoints
        real(c_double),     intent(in)  :: p_rho(0:), p_gamma(0:), p_tau(0:)
        real(c_double),     intent(out) :: p_f(0:), p_f_rho(0:)
        real(c_double),     intent(out) :: p_f_gamma(0:), p_f_tau(0:)
        integer,            intent(in)  :: is_spin_polarized
        real(c_double), parameter :: RHO_THRESHOLD = 1.0d-15
        real(c_double) :: rho, tau, rho_s, tau_s, f_s, df_drho_s, df_dtau_s
        real(c_double) :: f_total_per_vol
        real(c_double) :: rho_a, rho_b, rho_total, tau_a, tau_b
        real(c_double) :: f_a, df_drho_a, df_dtau_a
        real(c_double) :: f_b, df_drho_b, df_dtau_b
        integer :: i

        ! LTA has no gradient dependence; p_gamma is accepted and ignored
        ! (the C sample writes `(void) p_gamma;` for the same reason).
        associate (unused_gamma => p_gamma); end associate

        if (is_spin_polarized == 0) then
            do i = 0, int(npoints)-1
                rho = p_rho(i)
                tau = p_tau(i)
                if (rho < RHO_THRESHOLD) then
                    p_f(i)       = 0.0d0
                    p_f_rho(i)   = 0.0d0
                    p_f_gamma(i) = 0.0d0
                    p_f_tau(i)   = 0.0d0
                    cycle
                end if
                rho_s = 0.5d0 * rho
                tau_s = 0.5d0 * tau
                call lta_eval_one_channel(rho_s, tau_s, f_s, df_drho_s, df_dtau_s)
                ! Both spin channels contribute equally.
                f_total_per_vol = 2.0d0 * f_s
                p_f(i)       = f_total_per_vol / rho
                p_f_rho(i)   = df_drho_s
                p_f_gamma(i) = 0.0d0
                p_f_tau(i)   = df_dtau_s
            end do
        else
            do i = 0, int(npoints)-1
                rho_a = p_rho(2*i + 0)
                rho_b = p_rho(2*i + 1)
                rho_total = rho_a + rho_b
                tau_a = p_tau(2*i + 0)
                tau_b = p_tau(2*i + 1)
                if (rho_total < RHO_THRESHOLD) then
                    p_f(i)             = 0.0d0
                    p_f_rho(2*i + 0)   = 0.0d0
                    p_f_rho(2*i + 1)   = 0.0d0
                    p_f_gamma(3*i + 0) = 0.0d0
                    p_f_gamma(3*i + 1) = 0.0d0
                    p_f_gamma(3*i + 2) = 0.0d0
                    p_f_tau(2*i + 0)   = 0.0d0
                    p_f_tau(2*i + 1)   = 0.0d0
                    cycle
                end if
                call lta_eval_one_channel(rho_a, tau_a, f_a, df_drho_a, df_dtau_a)
                call lta_eval_one_channel(rho_b, tau_b, f_b, df_drho_b, df_dtau_b)
                p_f(i)             = (f_a + f_b) / rho_total
                p_f_rho(2*i + 0)   = df_drho_a
                p_f_rho(2*i + 1)   = df_drho_b
                p_f_gamma(3*i + 0) = 0.0d0
                p_f_gamma(3*i + 1) = 0.0d0
                p_f_gamma(3*i + 2) = 0.0d0
                p_f_tau(2*i + 0)   = df_dtau_a
                p_f_tau(2*i + 1)   = df_dtau_b
            end do
        end if
    end subroutine my_xc_mgga_exc_vxc

    ! ========================================================================
    !  Grid sanitizers. The C sample's `!(x >= y)` idiom is a "<" test that
    !  also fires on NaN; `.not. (x >= y)` has exactly the same behaviour.
    ! ========================================================================

    subroutine sanitize_grid_rks_lda(npoint, h_rho)
        integer(c_int64_t), intent(in)    :: npoint
        real(c_double),     intent(inout) :: h_rho(0:)
        integer(c_int64_t) :: kept, zeroed
        integer :: i
        kept = 0
        zeroed = 0
        do i = 0, int(npoint)-1
            if (.not. (h_rho(i) >= SANITIZE_RHO_SAFE)) then
                h_rho(i) = 0.0d0
                zeroed = zeroed + 1
            else
                kept = kept + 1
            end if
        end do
        write(*,'(A,I0,A,I0,A,I0,A)') " >> sanitize_grid_rks_lda: kept ", kept, &
            " / ", npoint, " points (zeroed ", zeroed, ")"
    end subroutine sanitize_grid_rks_lda

    subroutine sanitize_grid_uks_lda(npoint, h_rho)
        integer(c_int64_t), intent(in)    :: npoint
        real(c_double),     intent(inout) :: h_rho(0:)
        integer(c_int64_t) :: kept, zeroed
        integer :: i
        logical :: zero_out
        real(c_double) :: rt
        kept = 0
        zeroed = 0
        do i = 0, int(npoint)-1
            zero_out = .false.
            if (.not. (h_rho(2*i + 0) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. (h_rho(2*i + 1) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. zero_out) then
                rt = h_rho(2*i + 0) + h_rho(2*i + 1)
                if (2.0d0 * h_rho(2*i + 0) < SANITIZE_ZETA_SAFE * rt) zero_out = .true.
                if (2.0d0 * h_rho(2*i + 1) < SANITIZE_ZETA_SAFE * rt) zero_out = .true.
            end if
            if (zero_out) then
                h_rho(2*i + 0) = 0.0d0
                h_rho(2*i + 1) = 0.0d0
                zeroed = zeroed + 1
            else
                kept = kept + 1
            end if
        end do
        write(*,'(A,I0,A,I0,A,I0,A)') " >> sanitize_grid_uks_lda: kept ", kept, &
            " / ", npoint, " points (zeroed ", zeroed, ")"
    end subroutine sanitize_grid_uks_lda

    subroutine sanitize_grid_uks_mgga(npoint, h_rho, h_tau)
        integer(c_int64_t), intent(in)    :: npoint
        real(c_double),     intent(inout) :: h_rho(0:), h_tau(0:)
        integer(c_int64_t) :: kept, zeroed
        integer :: i
        logical :: zero_out
        real(c_double) :: rt
        kept = 0
        zeroed = 0
        do i = 0, int(npoint)-1
            zero_out = .false.
            if (.not. (h_rho(2*i + 0) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. (h_rho(2*i + 1) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. zero_out) then
                rt = h_rho(2*i + 0) + h_rho(2*i + 1)
                if (2.0d0 * h_rho(2*i + 0) < SANITIZE_ZETA_MGGA * rt) zero_out = .true.
                if (2.0d0 * h_rho(2*i + 1) < SANITIZE_ZETA_MGGA * rt) zero_out = .true.
            end if
            if (zero_out) then
                h_rho(2*i + 0) = 0.0d0
                h_rho(2*i + 1) = 0.0d0
                h_tau(2*i + 0) = 0.0d0
                h_tau(2*i + 1) = 0.0d0
                zeroed = zeroed + 1
            else
                kept = kept + 1
            end if
        end do
        write(*,'(A,I0,A,I0,A,I0,A)') " >> sanitize_grid_uks_mgga: kept ", kept, &
            " / ", npoint, " points (zeroed ", zeroed, ")"
    end subroutine sanitize_grid_uks_mgga

    subroutine sanitize_grid_rks_gga(npoint, h_rho, h_gamma)
        integer(c_int64_t), intent(in)    :: npoint
        real(c_double),     intent(inout) :: h_rho(0:), h_gamma(0:)
        integer(c_int64_t) :: kept, zeroed
        integer :: i
        logical :: zero_out
        real(c_double) :: rho_13_, rho_43_, rho_83_, gamma_eff
        kept = 0
        zeroed = 0
        do i = 0, int(npoint)-1
            zero_out = .false.
            if (.not. (h_rho(i)   >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. (h_gamma(i) >= 0.0d0))             zero_out = .true.
            if (.not. zero_out) then
                rho_13_   = cbrt(h_rho(i))
                rho_43_   = h_rho(i) * rho_13_
                rho_83_   = rho_43_ * rho_43_
                gamma_eff = h_gamma(i) * cbrt(4.0d0)
                if (gamma_eff > SANITIZE_XS_SQ_MAX * rho_83_) zero_out = .true.
            end if
            if (zero_out) then
                h_rho(i)   = 0.0d0
                h_gamma(i) = 0.0d0
                zeroed = zeroed + 1
            else
                kept = kept + 1
            end if
        end do
        write(*,'(A,I0,A,I0,A,I0,A)') " >> sanitize_grid_rks_gga: kept ", kept, &
            " / ", npoint, " points (zeroed ", zeroed, ")"
    end subroutine sanitize_grid_rks_gga

    subroutine sanitize_grid_uks_gga(npoint, h_rho, h_gamma)
        integer(c_int64_t), intent(in)    :: npoint
        real(c_double),     intent(inout) :: h_rho(0:), h_gamma(0:)
        integer(c_int64_t) :: kept, zeroed
        integer :: i
        logical :: zero_out
        real(c_double) :: rt, s_max
        real(c_double) :: rho_a_13, rho_a_43, rho_a_83
        real(c_double) :: rho_b_13, rho_b_43, rho_b_83
        kept = 0
        zeroed = 0
        do i = 0, int(npoint)-1
            zero_out = .false.
            if (.not. (h_rho(2*i + 0) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. (h_rho(2*i + 1) >= SANITIZE_RHO_SAFE)) zero_out = .true.
            if (.not. zero_out) then
                rt = h_rho(2*i + 0) + h_rho(2*i + 1)
                if (2.0d0 * h_rho(2*i + 0) < SANITIZE_ZETA_SAFE * rt) zero_out = .true.
                if (2.0d0 * h_rho(2*i + 1) < SANITIZE_ZETA_SAFE * rt) zero_out = .true.
            end if
            if (.not. (h_gamma(3*i + 0) >= 0.0d0)) zero_out = .true.
            if (.not. (h_gamma(3*i + 2) >= 0.0d0)) zero_out = .true.
            if (.not. ieee_is_finite(h_gamma(3*i + 1))) zero_out = .true.
            ! Per-spin reduced-gradient ceiling: sigma_ss <= XS_SQ_MAX * rho_s^(8/3)
            if (.not. zero_out) then
                rho_a_13 = cbrt(h_rho(2*i + 0))
                rho_a_43 = h_rho(2*i + 0) * rho_a_13
                rho_a_83 = rho_a_43 * rho_a_43
                if (h_gamma(3*i + 0) > SANITIZE_XS_SQ_MAX * rho_a_83) zero_out = .true.
            end if
            if (.not. zero_out) then
                rho_b_13 = cbrt(h_rho(2*i + 1))
                rho_b_43 = h_rho(2*i + 1) * rho_b_13
                rho_b_83 = rho_b_43 * rho_b_43
                if (h_gamma(3*i + 2) > SANITIZE_XS_SQ_MAX * rho_b_83) zero_out = .true.
            end if

            if (zero_out) then
                h_rho(2*i + 0)   = 0.0d0
                h_rho(2*i + 1)   = 0.0d0
                h_gamma(3*i + 0) = 0.0d0
                h_gamma(3*i + 1) = 0.0d0
                h_gamma(3*i + 2) = 0.0d0
                zeroed = zeroed + 1
                cycle
            end if

            ! Cauchy-Schwarz clip on the cross-spin term.
            s_max = sqrt(h_gamma(3*i + 0) * h_gamma(3*i + 2))
            if (h_gamma(3*i + 1) >  s_max) h_gamma(3*i + 1) =  s_max
            if (h_gamma(3*i + 1) < -s_max) h_gamma(3*i + 1) = -s_max
            kept = kept + 1
        end do
        write(*,'(A,I0,A,I0,A,I0,A)') " >> sanitize_grid_uks_gga: kept ", kept, &
            " / ", npoint, " points (zeroed ", zeroed, ")"
    end subroutine sanitize_grid_uks_gga

    ! ========================================================================
    !  Small utilities
    ! ========================================================================

    !> M x N row-major matrix of N(0,1) deviates, copied to the device.
    !  Exact transcription of the C sample's fill_matrix().
    subroutine fill_matrix(dev, m, n)
        type(c_ptr),        intent(in) :: dev
        integer(c_int64_t), intent(in) :: m, n
        real(c_double), allocatable, target :: atmp(:)
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

    !> Copy `n` doubles from a host array to a device buffer.
    subroutine host_to_dev(dev, host, n)
        type(c_ptr),        intent(in)         :: dev
        real(c_double),     intent(in), target :: host(0:)
        integer(c_int64_t), intent(in)         :: n
        call cuda_ck(cudaMemcpy(dev, c_loc(host), &
                     int(n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                     "cudaMemcpy(H2D)")
    end subroutine host_to_dev

end program advanced_local_xc_potential
