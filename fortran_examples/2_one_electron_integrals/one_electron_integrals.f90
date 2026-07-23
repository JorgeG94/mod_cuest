! ============================================================================
!  one_electron_integrals.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/2_one_electron_integrals/
!    one_electron_integrals/main.c
!
!  Computes the overlap (S), kinetic (T) and nuclear attraction (V) matrices
!  for a molecule read from an XYZ file in a basis read from a GBS file.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> AO pair list -> OE integral plan
!           -> S, T, V into device buffers
!
!  Difference from the C sample: it computes the integrals and exits without
!  printing them. This port prints a numeric fingerprint of each matrix, so
!  the result can actually be checked and compared.
!
!  Usage:  ./one_electron_integrals <xyz_file> <gbs_file>
! ============================================================================
program one_electron_integrals
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
    implicit none

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: pl_par = c_null_ptr, plan_par = c_null_ptr
    type(c_ptr) :: s_par = c_null_ptr, t_par = c_null_ptr, v_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_s = c_null_ptr, d_t = c_null_ptr, d_v = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    integer(c_int64_t) :: nao = 0, num_atoms
    real(c_double), allocatable :: h_mat(:)
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST one-electron integrals (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry (also mirrors coords/charges to device) -----
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

    ! ---- 7. device buffers for S, T, V -------------------------------------
    d_s = dev_alloc(nao*nao)
    d_t = dev_alloc(nao*nao)
    d_v = dev_alloc(nao*nao)
    allocate(h_mat(nao*nao))

    ! ---- 8. overlap --------------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_OVERLAPCOMPUTE_PARAMETERS, s_par), &
                     "ParametersCreate(overlap)")
    call cuest_check(cuestOverlapComputeWorkspaceQuery(handle, plan, s_par, &
                     d_temp, d_s), "OverlapComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestOverlapCompute(handle, plan, s_par, ws_tmp, d_s), &
                     "cuestOverlapCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_OVERLAPCOMPUTE_PARAMETERS, s_par), &
                     "ParametersDestroy(overlap)")

    ! ---- 9. kinetic --------------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_KINETICCOMPUTE_PARAMETERS, t_par), &
                     "ParametersCreate(kinetic)")
    call cuest_check(cuestKineticComputeWorkspaceQuery(handle, plan, t_par, &
                     d_temp, d_t), "KineticComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestKineticCompute(handle, plan, t_par, ws_tmp, d_t), &
                     "cuestKineticCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_KINETICCOMPUTE_PARAMETERS, t_par), &
                     "ParametersDestroy(kinetic)")

    ! ---- 10. nuclear attraction (device coords + charges) ------------------
    call cuest_check(cuestParametersCreate(CUEST_POTENTIALCOMPUTE_PARAMETERS, v_par), &
                     "ParametersCreate(potential)")
    call cuest_check(cuestPotentialComputeWorkspaceQuery(handle, plan, v_par, &
                     d_temp, num_atoms, xyz%xyz_gpu, xyz%charges_gpu, d_v), &
                     "PotentialComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestPotentialCompute(handle, plan, v_par, ws_tmp, &
                     num_atoms, xyz%xyz_gpu, xyz%charges_gpu, d_v), &
                     "cuestPotentialCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_POTENTIALCOMPUTE_PARAMETERS, v_par), &
                     "ParametersDestroy(potential)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 11. report --------------------------------------------------------
    write(*,'(A)') ""
    call dev_to_host(h_mat, d_s, nao*nao)
    call matrix_report("S (overlap)", h_mat, nao)
    call dev_to_host(h_mat, d_t, nao*nao)
    call matrix_report("T (kinetic)", h_mat, nao)
    call dev_to_host(h_mat, d_v, nao*nao)
    call matrix_report("V (nuclear attraction)", h_mat, nao)

    ! ---- 12. teardown ------------------------------------------------------
    deallocate(h_mat)
    call dev_free(d_s)
    call dev_free(d_t)
    call dev_free(d_v)

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

end program one_electron_integrals
