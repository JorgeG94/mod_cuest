! ============================================================================
!  ao_basis_general.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    ao_basis_general/main.c
!
!  Builds an AO basis handle for an arbitrary molecule and basis set, using the
!  XYZ and GBS helpers rather than hardcoded shell data, then reports the size
!  of the workspaces the basis needed and the attributes of the basis itself.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells (helper) -> AO basis (query -> allocate -> create)
!           -> cuestQuery
!
!  Difference from the C sample: the C prints the numbers in a form nothing can
!  parse, so each is additionally emitted as a scalar report section. The
!  oracle emits the identical sections.
!
!  Usage:  ./ao_basis_general <xyz_file> <gbs_file>
! ============================================================================
program ao_basis_general
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64, cuest_query_i32
    use cuest_sample_utils, only: cuest_check, scalar_report, ws_alloc, ws_free, &
                                  arg, require_args
    use xyz_parser
    use ao_shells
    implicit none

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t

    integer(c_int64_t) :: num_atoms
    integer(c_int64_t) :: natom = 0, nshell = 0, nao = 0, ncart = 0
    integer(c_int64_t) :: nprimitive = 0, max_l = 0
    integer(c_int32_t) :: is_pure_basis = 0
    integer(c_size_t)  :: ws_p_host, ws_p_dev, ws_t_host, ws_t_dev
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. AO shells from the GBS file ------------------------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd)

    ! The geometry is not needed past this point, as in the C sample.
    call free_parsed_xyz(xyz)

    ! ---- 4. AO basis (query -> allocate -> create) -------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersCreate(basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     d_persist, d_temp, basis), "AOBasisCreateWorkspaceQuery")

    ws_p_host = d_persist%hostBufferSizeInBytes
    ws_p_dev  = d_persist%deviceBufferSizeInBytes
    ws_t_host = d_temp%hostBufferSizeInBytes
    ws_t_dev  = d_temp%deviceBufferSizeInBytes

    write(*,'(A)') "AO Basis Workspace Descriptors"
    write(*,'(A,I0)') "Persistent CPU Workspace: ", ws_p_host
    write(*,'(A,I0)') "Persistent GPU Workspace: ", ws_p_dev
    write(*,'(A,I0)') "Temporary CPU Workspace:  ", ws_t_host
    write(*,'(A,I0)') "Temporary GPU Workspace:  ", ws_t_dev
    write(*,'(A)') ""

    call ws_alloc(ws_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     ws_basis, ws_tmp, basis), "cuestAOBasisCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersDestroy(basis)")

    call free_ao_shell_data(sd)

    ! ---- 5. query the finished basis ---------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_ATOM, natom), "query NUM_ATOM")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_SHELL, nshell), "query NUM_SHELL")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_CART, ncart), "query NUM_CART")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_PRIMITIVE, nprimitive), "query NUM_PRIMITIVE")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_MAX_L, max_l), "query MAX_L")
    call cuest_check(cuest_query_i32(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_IS_PURE, is_pure_basis), "query IS_PURE")

    write(*,'(A)') "AO Basis from handle:"
    write(*,'(A,I6)') "natom      = ", natom
    write(*,'(A,I6)') "nshell     = ", nshell
    write(*,'(A,I6)') "nao        = ", nao
    write(*,'(A,I6)') "ncart      = ", ncart
    write(*,'(A,I6)') "nprimitive = ", nprimitive
    write(*,'(A,I6)') "max_L      = ", max_l
    if (is_pure_basis /= 0) then
        write(*,'(A)') "is_pure    =   true"
    else
        write(*,'(A)') "is_pure    =  false"
    end if

    ! ---- 6. report ---------------------------------------------------------
    call scalar_report("workspace persistent host bytes", real(ws_p_host, c_double))
    call scalar_report("workspace persistent device bytes", real(ws_p_dev, c_double))
    call scalar_report("workspace temporary host bytes", real(ws_t_host, c_double))
    call scalar_report("workspace temporary device bytes", real(ws_t_dev, c_double))

    call scalar_report("basis natom",      real(natom,      c_double))
    call scalar_report("basis nshell",     real(nshell,     c_double))
    call scalar_report("basis nao",        real(nao,        c_double))
    call scalar_report("basis ncart",      real(ncart,      c_double))
    call scalar_report("basis nprimitive", real(nprimitive, c_double))
    call scalar_report("basis max_L",      real(max_l,      c_double))
    call scalar_report("basis is_pure",    real(is_pure_basis, c_double))

    ! ---- 7. teardown -------------------------------------------------------
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    ist = cuestDestroy(handle)

end program ao_basis_general
