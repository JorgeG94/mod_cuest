! ============================================================================
!  nonsymmetric_core_df_k.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/3_density_fitting/
!    nonsymmetric_core_df_k/main.c
!
!  Builds a set of nonsymmetric density-fitted exchange matrices. The
!  nonsymmetric variant takes ONE left coefficient matrix and a stack of
!  numCoefficientMatrices right coefficient matrices, and produces one K
!  matrix per right matrix.
!
!  Density fitting needs a second basis set, so TWO AO bases are built:
!
!    primary (orbital) basis   <- argv(2)   -> AO pair list, nao, K dimension
!    auxiliary (fitting) basis <- argv(3)   -> the fitting side of the DF plan
!
!  Structure follows the C sample call for call:
!    handle -> primary shells/basis -> auxiliary shells/basis
!           -> AO pair list (primary basis) -> DF integral plan (both bases)
!           -> 4 exchange matrices from Cleft and 4 stacked Cright blocks
!
!  The C sample has no real MO coefficients to work with, so it synthesises
!  them with fill_matrix(): Box-Muller normal deviates drawn from libc rand()
!  after srand(0). This port calls the very same libc rand()/srand() through
!  iso_c_binding, in the same order, so the inputs are bit-identical to the C
!  reference rather than merely similar.
!
!  Difference from the C sample: it computes the K matrices and exits without
!  printing them. This port prints a numeric fingerprint of each.
!
!  Usage:
!    ./nonsymmetric_core_df_k <xyz_file> <primary_gbs_file> <auxiliary_gbs_file>
! ============================================================================
program nonsymmetric_core_df_k
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
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

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd_pri, sd_aux

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr
    type(c_ptr) :: pri_bas_par = c_null_ptr, aux_bas_par = c_null_ptr
    type(c_ptr) :: pl_par = c_null_ptr, plan_par = c_null_ptr
    type(c_ptr) :: k_par = c_null_ptr
    type(c_ptr) :: pri_basis = c_null_ptr, aux_basis = c_null_ptr
    type(c_ptr) :: pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_k = c_null_ptr, d_cleft = c_null_ptr, d_cright = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
    type(cuestWorkspace_t) :: ws_pri_basis, ws_aux_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t), parameter :: NUM_COEFF_MATRICES = 4_c_int64_t
    integer(c_int64_t) :: nao = 0, nocc = 0, num_atoms, off
    real(c_double), allocatable :: h_k(:), h_c(:)
    character(len=16) :: label
    integer(c_int) :: ist
    integer :: i, m

    call require_args(3, "<xyz_file> <primary_gbs_file> <auxiliary_gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST nonsymmetric core DF K (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)
    write(*,'(A,A)') "  aux basis: ", arg(3)

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

    ! ---- 3. AO shells + basis, primary (orbital) basis ---------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd_pri)
    write(*,'(A,I0)') "  shells   : ", sd_pri%num_shells_total

    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, pri_bas_par), &
                     "ParametersCreate(primary basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, num_atoms, &
                     sd_pri%num_shells_per_atom, sd_pri%shells, pri_bas_par, &
                     d_persist, d_temp, pri_basis), &
                     "AOBasisCreateWorkspaceQuery(primary)")
    call ws_alloc(ws_pri_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, num_atoms, &
                     sd_pri%num_shells_per_atom, sd_pri%shells, pri_bas_par, &
                     ws_pri_basis, ws_tmp, pri_basis), &
                     "cuestAOBasisCreate(primary)")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, pri_bas_par), &
                     "ParametersDestroy(primary basis)")
    call free_ao_shell_data(sd_pri)

    ! ---- 4. AO shells + basis, auxiliary (fitting) basis -------------------
    call form_ao_shells(handle, xyz, arg(3), IS_PURE, sd_aux)
    write(*,'(A,I0)') "  aux shls : ", sd_aux%num_shells_total

    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, aux_bas_par), &
                     "ParametersCreate(auxiliary basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, num_atoms, &
                     sd_aux%num_shells_per_atom, sd_aux%shells, aux_bas_par, &
                     d_persist, d_temp, aux_basis), &
                     "AOBasisCreateWorkspaceQuery(auxiliary)")
    call ws_alloc(ws_aux_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, num_atoms, &
                     sd_aux%num_shells_per_atom, sd_aux%shells, aux_bas_par, &
                     ws_aux_basis, ws_tmp, aux_basis), &
                     "cuestAOBasisCreate(auxiliary)")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, aux_bas_par), &
                     "ParametersDestroy(auxiliary basis)")
    call free_ao_shell_data(sd_aux)

    ! ---- 5. AO pair list -- primary basis, host coordinates ----------------
    call cuest_check(cuestParametersCreate(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersCreate(pair list)")
    call make_pair_list()
    call cuest_check(cuestParametersDestroy(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersDestroy(pair list)")

    ! ---- 6. density-fitted integral plan (primary + auxiliary) -------------
    call cuest_check(cuestParametersCreate(CUEST_DFINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(DF plan)")
    call cuest_check(cuestDFIntPlanCreateWorkspaceQuery(handle, pri_basis, &
                     aux_basis, pair_list, plan_par, d_persist, d_temp, plan), &
                     "DFIntPlanCreateWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestDFIntPlanCreate(handle, pri_basis, aux_basis, &
                     pair_list, plan_par, ws_plan, ws_tmp, plan), &
                     "cuestDFIntPlanCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_DFINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(DF plan)")

    ! ---- 7. dimensions -----------------------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, pri_basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO(primary)")
    write(*,'(A,I0)') "  nao      : ", nao

    ! nocc for a neutral molecule; charges are stored as -Z, so -1*charge = Z
    nocc = 0
    do i = 1, int(xyz%num_atoms)
        nocc = nocc + int(-1.0d0 * xyz%charges_cpu(i), c_int64_t)
    end do
    nocc = nocc / 2
    write(*,'(A,I0)') "  nocc     : ", nocc

    ! ---- 8. device buffers -------------------------------------------------
    d_k      = dev_alloc(NUM_COEFF_MATRICES * nao * nao)
    d_cleft  = dev_alloc(nocc * nao)
    d_cright = dev_alloc(NUM_COEFF_MATRICES * nocc * nao)

    ! Synthetic MO coefficients, identical to the C sample's fill_matrix().
    call fill_matrix(d_cleft,  nocc, nao)
    call fill_matrix(d_cright, NUM_COEFF_MATRICES * nocc, nao)

    ! ---- 9. exchange matrices ----------------------------------------------
    !
    ! The DF-K algorithm can exploit a very large temporary space. A workspace
    ! descriptor caps the size of certain intermediates; 2 GB is the value the
    ! C sample uses and is a reasonable default.
    call cuest_check(cuestParametersCreate(CUEST_DFNONSYMMETRICEXCHANGECOMPUTE_PARAMETERS, &
                     k_par), "ParametersCreate(DF nonsymmetric exchange)")
    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestDFNonsymmetricExchangeComputeWorkspaceQuery(handle, &
                     plan, k_par, var_buf, d_temp, NUM_COEFF_MATRICES, nocc, &
                     d_cleft, d_cright, d_k), &
                     "DFNonsymmetricExchangeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestDFNonsymmetricExchangeCompute(handle, plan, k_par, &
                     var_buf, ws_tmp, NUM_COEFF_MATRICES, nocc, d_cleft, &
                     d_cright, d_k), "cuestDFNonsymmetricExchangeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_DFNONSYMMETRICEXCHANGECOMPUTE_PARAMETERS, &
                     k_par), "ParametersDestroy(DF nonsymmetric exchange)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 10. report --------------------------------------------------------
    write(*,'(A)') ""
    allocate(h_k(NUM_COEFF_MATRICES*nao*nao), h_c(NUM_COEFF_MATRICES*nocc*nao))

    call dev_to_host(h_c, d_cleft, nocc*nao)
    call array_report("Cleft (MO coefficients)", h_c, nocc*nao)
    call dev_to_host(h_c, d_cright, NUM_COEFF_MATRICES*nocc*nao)
    call array_report("Cright (MO coefficients)", h_c, NUM_COEFF_MATRICES*nocc*nao)

    call dev_to_host(h_k, d_k, NUM_COEFF_MATRICES*nao*nao)
    do m = 0, int(NUM_COEFF_MATRICES) - 1
        off = int(m, c_int64_t) * nao * nao
        write(label,'("K[",I0,"] (exchange)")') m
        call matrix_report(trim(label), h_k(off+1 : off+nao*nao), nao)
    end do

    ! ---- 11. teardown ------------------------------------------------------
    deallocate(h_k, h_c)
    call dev_free(d_k)
    call dev_free(d_cleft)
    call dev_free(d_cright)

    ist = cuestDFIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestAOPairListDestroy(pair_list)
    call ws_free(ws_pl)
    ist = cuestAOBasisDestroy(aux_basis)
    call ws_free(ws_aux_basis)
    ist = cuestAOBasisDestroy(pri_basis)
    call ws_free(ws_pri_basis)
    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    !> The pair list takes HOST coordinates, so C_LOC needs a TARGET actual
    !  argument; wrapping it here keeps the main flow readable.
    subroutine make_pair_list()
        real(c_double), parameter :: TOL = 1.0d-14
        call cuest_check(cuestAOPairListCreateWorkspaceQuery(handle, pri_basis, &
                         num_atoms, c_loc(xyz%xyz_cpu), TOL, pl_par, &
                         d_persist, d_temp, pair_list), &
                         "AOPairListCreateWorkspaceQuery")
        call ws_alloc(ws_pl, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestAOPairListCreate(handle, pri_basis, num_atoms, &
                         c_loc(xyz%xyz_cpu), TOL, pl_par, ws_pl, ws_tmp, &
                         pair_list), "cuestAOPairListCreate")
        call ws_free(ws_tmp)
    end subroutine make_pair_list

    ! ------------------------------------------------------------------------
    !  Synthetic input data -- an exact transcription of the C sample's
    !  fill_matrix().
    !
    !  It draws from the C library's rand() after srand(0) and maps pairs of
    !  uniforms to a normal deviate with the Box-Muller transform. Binding
    !  directly to libc's srand/rand (rather than reimplementing glibc's
    !  generator) makes the stream identical by construction.
    ! ------------------------------------------------------------------------

    !> M x N row-major matrix of N(0,1) deviates, copied to the device.
    subroutine fill_matrix(dev, m, n)
        type(c_ptr),        intent(in) :: dev
        integer(c_int64_t), intent(in) :: m, n
        real(c_double), allocatable, target :: atmp(:)
        integer(c_int64_t) :: i, j, ij
        allocate(atmp(m*n))
        call c_srand(0_c_int)
        ij = 0
        do i = 1, m
            do j = 1, n
                ij = ij + 1
                atmp(ij) = normal_deviate()
            end do
        end do
        call cuda_ck(cudaMemcpy(dev, c_loc(atmp), &
                     int(m*n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                     "cudaMemcpy(fill_matrix H2D)")
        deallocate(atmp)
    end subroutine fill_matrix

    !> One Box-Muller normal deviate (mu = 0, sigma = 1) from two rand() draws.
    real(c_double) function normal_deviate() result(v)
        real(c_double), parameter :: PI = 3.14159265358979323846d0
        real(c_double), parameter :: SCALE = 2147483647.0d0 + 2.0d0   ! RAND_MAX + 2
        real(c_double) :: u1, u2
        u1 = (real(c_rand(), c_double) + 1.0d0) / SCALE
        u2 = (real(c_rand(), c_double) + 1.0d0) / SCALE
        v = sqrt(-2.0d0 * log(u1)) * cos(2.0d0 * PI * u2)
    end function normal_deviate

end program nonsymmetric_core_df_k
