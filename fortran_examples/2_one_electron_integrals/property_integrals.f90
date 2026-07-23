! ============================================================================
!  property_integrals.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/2_one_electron_integrals/
!    property_integrals/main.c
!
!  Computes three property (one-electron operator) integral matrices for a
!  molecule read from an XYZ file in a basis read from a GBS file:
!
!    L  angular momentum, Lz component, about the origin
!    N  nabla (momentum), x component
!    M  multipole of order (1,0,0) -- i.e. the x dipole -- about the origin
!
!  The operator settings are exactly the ones the C sample hard-codes.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> AO pair list -> OE integral plan
!           -> L, N, M into device buffers
!
!  Usage:  ./property_integrals <xyz_file> <gbs_file>
! ============================================================================
program property_integrals
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
    type(c_ptr) :: l_par = c_null_ptr, n_par = c_null_ptr, m_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_l = c_null_ptr, d_n = c_null_ptr, d_m = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t

    ! Example operator settings -- identical to the C sample.
    integer(c_int),     parameter :: ANGULAR_COMPONENT = &
        CUEST_ANGULARMOMENTUMCOMPUTE_PARAMETERS_COMPONENT_LZ
    integer(c_int),     parameter :: NABLA_COMPONENT = &
        CUEST_NABLACOMPUTE_PARAMETERS_COMPONENT_X
    integer(c_int32_t) :: multipole_order(3) = [1_c_int32_t, 0_c_int32_t, 0_c_int32_t]
    real(c_double), target :: origin(3) = [0.0d0, 0.0d0, 0.0d0]

    integer(c_int64_t) :: nao = 0, num_atoms
    real(c_double), allocatable :: h_mat(:)
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST property integrals (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry ---------------------------------------------
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

    ! ---- 7. device buffers for L, N, M -------------------------------------
    d_l = dev_alloc(nao*nao)
    d_n = dev_alloc(nao*nao)
    d_m = dev_alloc(nao*nao)
    allocate(h_mat(nao*nao))

    ! ---- 8. angular momentum (Lz about the origin) -------------------------
    call cuest_check(cuestParametersCreate( &
                     CUEST_ANGULARMOMENTUMCOMPUTE_PARAMETERS, l_par), &
                     "ParametersCreate(angular momentum)")
    call cuest_check(cuestAngularMomentumComputeWorkspaceQuery(handle, plan, &
                     l_par, d_temp, ANGULAR_COMPONENT, c_loc(origin), d_l), &
                     "AngularMomentumComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAngularMomentumCompute(handle, plan, l_par, ws_tmp, &
                     ANGULAR_COMPONENT, c_loc(origin), d_l), &
                     "cuestAngularMomentumCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_ANGULARMOMENTUMCOMPUTE_PARAMETERS, l_par), &
                     "ParametersDestroy(angular momentum)")

    ! ---- 9. nabla (x component) --------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_NABLACOMPUTE_PARAMETERS, n_par), &
                     "ParametersCreate(nabla)")
    call cuest_check(cuestNablaComputeWorkspaceQuery(handle, plan, n_par, &
                     d_temp, NABLA_COMPONENT, d_n), &
                     "NablaComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestNablaCompute(handle, plan, n_par, ws_tmp, &
                     NABLA_COMPONENT, d_n), "cuestNablaCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_NABLACOMPUTE_PARAMETERS, n_par), &
                     "ParametersDestroy(nabla)")

    ! ---- 10. multipole (order 1,0,0 about the origin) ----------------------
    call cuest_check(cuestParametersCreate(CUEST_MULTIPOLECOMPUTE_PARAMETERS, m_par), &
                     "ParametersCreate(multipole)")
    call cuest_check(cuestMultipoleComputeWorkspaceQuery(handle, plan, m_par, &
                     d_temp, multipole_order, c_loc(origin), d_m), &
                     "MultipoleComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestMultipoleCompute(handle, plan, m_par, ws_tmp, &
                     multipole_order, c_loc(origin), d_m), &
                     "cuestMultipoleCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_MULTIPOLECOMPUTE_PARAMETERS, m_par), &
                     "ParametersDestroy(multipole)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 11. report --------------------------------------------------------
    write(*,'(A)') ""
    call dev_to_host(h_mat, d_l, nao*nao)
    call matrix_report("L (angular momentum, Lz)", h_mat, nao)
    call dev_to_host(h_mat, d_n, nao*nao)
    call matrix_report("N (nabla, x)", h_mat, nao)
    call dev_to_host(h_mat, d_m, nao*nao)
    call matrix_report("M (multipole, order 1 0 0)", h_mat, nao)

    ! ---- 12. teardown ------------------------------------------------------
    deallocate(h_mat)
    call dev_free(d_l)
    call dev_free(d_n)
    call dev_free(d_m)

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

end program property_integrals
