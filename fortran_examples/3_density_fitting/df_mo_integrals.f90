! ============================================================================
!  df_mo_integrals.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/3_density_fitting/
!    df_mo_integrals/main.c
!
!  Transforms the AO three-index density-fitted tensor to the MO basis in
!  three blocks:
!    A_ij : auxiliary x occupied x occupied
!    A_ia : auxiliary x occupied x virtual
!    A_ab : auxiliary x virtual  x virtual
!
!  Density fitting needs a second basis set, so TWO AO bases are built:
!
!    primary (orbital) basis   <- argv(2)   -> AO pair list, nao
!    auxiliary (fitting) basis <- argv(3)   -> naux, fitting side of the plan
!
!  Structure follows the C sample call for call:
!    handle -> primary shells/basis -> auxiliary shells/basis
!           -> AO pair list (primary basis) -> DF integral plan (both bases)
!           -> DF MO integrals for the three (left, right) orbital-space pairs
!
!  The C sample has no real MO coefficients to work with, so it synthesises
!  them with fill_matrix(): Box-Muller normal deviates drawn from libc rand()
!  after srand(0). This port calls the very same libc rand()/srand() through
!  iso_c_binding, in the same order, so the inputs are bit-identical to the C
!  reference rather than merely similar.
!
!  Difference from the C sample: it computes the tensors and exits without
!  printing them. This port prints a numeric fingerprint of each block.
!
!  Usage:
!    ./df_mo_integrals <xyz_file> <primary_gbs_file> <auxiliary_gbs_file>
! ============================================================================
program df_mo_integrals
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
    type(c_ptr) :: mo_par = c_null_ptr
    type(c_ptr) :: pri_basis = c_null_ptr, aux_basis = c_null_ptr
    type(c_ptr) :: pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_cleft = c_null_ptr, d_cright = c_null_ptr
    type(c_ptr) :: d_tensors = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
    type(cuestWorkspace_t) :: ws_pri_basis, ws_aux_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t), parameter :: NUM_COEFF_MATRICES = 3_c_int64_t
    integer(c_int64_t) :: nao = 0, naux = 0, nocc = 0, nvir, num_atoms
    integer(c_int64_t) :: num_left(3), num_right(3)
    integer(c_int64_t) :: total_left_rows, total_right_rows, total_block_size
    integer(c_int64_t) :: off, blk
    real(c_double), allocatable :: h_cl(:), h_cr(:), h_t(:)
    integer(c_int) :: ist
    integer :: i, k

    call require_args(3, "<xyz_file> <primary_gbs_file> <auxiliary_gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST DF MO integrals (Fortran port) -- headers v", &
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
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, aux_basis, &
                     CUEST_AOBASIS_NUM_AO, naux), "query NUM_AO(auxiliary)")
    write(*,'(A,I0)') "  nao      : ", nao
    write(*,'(A,I0)') "  naux     : ", naux

    ! nocc for a neutral molecule; charges are stored as -Z, so -1*charge = Z
    nocc = 0
    do i = 1, int(xyz%num_atoms)
        nocc = nocc + int(-1.0d0 * xyz%charges_cpu(i), c_int64_t)
    end do
    nocc = nocc / 2

    ! nvir is whatever is left over; in practice it comes from an SCF/MO step.
    if (nao > nocc) then
        nvir = nao - nocc
    else
        nvir = 0
    end if
    if (nvir == 0) then
        write(*,'(A)') "No virtual orbitals available in this simple example."
        error stop 1
    end if
    write(*,'(A,I0)') "  nocc     : ", nocc
    write(*,'(A,I0)') "  nvir     : ", nvir

    ! Coefficient-matrix pairs: 0 -> A_ij, 1 -> A_ia, 2 -> A_ab
    num_left(1)  = nocc
    num_right(1) = nocc
    num_left(2)  = nocc
    num_right(2) = nvir
    num_left(3)  = nvir
    num_right(3) = nvir

    total_left_rows  = num_left(1)  + num_left(2)  + num_left(3)
    total_right_rows = num_right(1) + num_right(2) + num_right(3)

    total_block_size = 0
    do k = 1, int(NUM_COEFF_MATRICES)
        total_block_size = total_block_size + num_left(k) * num_right(k)
    end do

    ! ---- 8. device buffers -------------------------------------------------
    d_cleft   = dev_alloc(total_left_rows  * nao)
    d_cright  = dev_alloc(total_right_rows * nao)
    d_tensors = dev_alloc(naux * total_block_size)

    ! Synthetic MO coefficients, identical to the C sample's fill_matrix().
    call fill_matrix(d_cleft,  total_left_rows,  nao)
    call fill_matrix(d_cright, total_right_rows, nao)

    ! ---- 9. DF MO integral transformation ----------------------------------
    !
    ! The transformation can exploit a large temporary space. A workspace
    ! descriptor caps the size of an internal scratch buffer; 2 GB is the value
    ! the C sample uses and is a reasonable default.
    call cuest_check(cuestParametersCreate(CUEST_DFMOINTEGRALSCOMPUTE_PARAMETERS, &
                     mo_par), "ParametersCreate(DF MO integrals)")
    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = 2000000000_c_size_t

    call cuest_check(cuestDFMOIntegralsComputeWorkspaceQuery(handle, plan, &
                     mo_par, var_buf, d_temp, NUM_COEFF_MATRICES, num_left, &
                     num_right, d_cleft, d_cright, d_tensors), &
                     "DFMOIntegralsComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestDFMOIntegralsCompute(handle, plan, mo_par, var_buf, &
                     ws_tmp, NUM_COEFF_MATRICES, num_left, num_right, &
                     d_cleft, d_cright, d_tensors), &
                     "cuestDFMOIntegralsCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_DFMOINTEGRALSCOMPUTE_PARAMETERS, &
                     mo_par), "ParametersDestroy(DF MO integrals)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 10. report --------------------------------------------------------
    write(*,'(A)') ""
    allocate(h_cl(total_left_rows * nao), h_cr(total_right_rows * nao), &
             h_t(naux * total_block_size))

    call dev_to_host(h_cl, d_cleft, total_left_rows*nao)
    call array_report("Cleft (MO coefficients)", h_cl, total_left_rows*nao)
    call dev_to_host(h_cr, d_cright, total_right_rows*nao)
    call array_report("Cright (MO coefficients)", h_cr, total_right_rows*nao)

    call dev_to_host(h_t, d_tensors, naux*total_block_size)
    off = 0
    blk = naux * num_left(1) * num_right(1)
    call array_report("A_ij block", h_t(off+1 : off+blk), blk)
    off = off + blk
    blk = naux * num_left(2) * num_right(2)
    call array_report("A_ia block", h_t(off+1 : off+blk), blk)
    off = off + blk
    blk = naux * num_left(3) * num_right(3)
    call array_report("A_ab block", h_t(off+1 : off+blk), blk)
    call array_report("DF MO tensors (all blocks)", h_t, naux*total_block_size)

    ! ---- 11. teardown ------------------------------------------------------
    deallocate(h_cl, h_cr, h_t)
    call dev_free(d_cleft)
    call dev_free(d_cright)
    call dev_free(d_tensors)

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

end program df_mo_integrals
