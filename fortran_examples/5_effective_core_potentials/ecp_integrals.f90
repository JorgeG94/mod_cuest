! ============================================================================
!  ecp_integrals.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/5_effective_core_potentials/
!    ecp_integrals/main.c
!
!  Computes the effective-core-potential contribution to the one-electron
!  Hamiltonian for a molecule whose heavy atoms carry an ECP.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> ECP shells -> ECP atoms
!           -> ECP integral plan -> ECP matrix into a device buffer
!
!  The ECP shell/atom set is built only for the elements that actually have an
!  ECP block in the ECP file. parse_ecp_for_element reports that through its
!  `found` flag, which is the Fortran counterpart of the C helper's NULL
!  return; the sample skips those elements exactly where the C sample tests
!  `if (!shellList[i]) continue;`. For CH2I2 with def2-svp-ecp only iodine has
!  an ECP, so only the two iodines become active ECP centres.
!
!  Difference from the C sample: it computes the ECP matrix and exits without
!  printing it. This port prints a numeric fingerprint, so the result can
!  actually be checked against the C oracle.
!
!  Usage:  ./ecp_integrals <xyz_file> <gbs_file> <ecp_file>
! ============================================================================
program ecp_integrals
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
    use ecp_parser
    implicit none

    !> One element's cuEST ECP shell handles: the local ("top") shell plus the
    !  semi-local shells. The C sample keeps these in two arrays of pointers
    !  indexed by unique element; a small derived type is the Fortran shape of
    !  the same thing, and it copes with the per-element shell counts.
    type :: ecp_pack_t
        type(c_ptr) :: top = c_null_ptr
        type(c_ptr), allocatable :: shells(:)
    end type ecp_pack_t

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: shell_par = c_null_ptr, atom_par = c_null_ptr
    type(c_ptr) :: plan_par = c_null_ptr, comp_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_ecp = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp, var_buf
    type(cuestWorkspace_t) :: ws_basis, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    !> The C sample offers the ECP compute a 2 GB variable device buffer.
    integer(c_size_t),  parameter :: VARIABLE_DEVICE_BYTES = 2000000000_c_size_t

    character(len=2), allocatable :: unique(:)
    type(ecp_shell_set_t), allocatable :: shell_list(:)
    logical,               allocatable :: has_ecp(:)
    type(ecp_pack_t),      allocatable :: packs(:)
    type(c_ptr),           allocatable :: ecp_atoms(:)
    integer(c_int64_t),    allocatable :: ecp_indices(:), ecp_map(:)

    integer(c_int64_t) :: nao = 0, num_atoms, num_active
    integer(c_int64_t) :: l, np, off, n_sh, nelec
    integer :: nat, n_unique, ia, j, k, bi
    real(c_double), allocatable :: h_mat(:)
    integer(c_int) :: ist
    logical :: is_new

    call require_args(3, "<xyz_file> <gbs_file> <ecp_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST ECP integrals (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)
    write(*,'(A,A)') "  ECP      : ", arg(3)

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms
    nat = int(num_atoms)
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

    ! The AO shells have been absorbed into the basis, as in the C sample.
    call free_ao_shell_data(sd)

    ! ---- 5. ECP definitions for the unique elements ------------------------
    allocate(unique(nat))
    n_unique = 0
    do ia = 1, nat
        is_new = .true.
        do j = 1, n_unique
            if (xyz%symbols(ia) == unique(j)) then
                is_new = .false.
                exit
            end if
        end do
        if (is_new) then
            n_unique = n_unique + 1
            unique(n_unique) = xyz%symbols(ia)
        end if
    end do

    allocate(shell_list(n_unique), has_ecp(n_unique))
    do j = 1, n_unique
        ! `has_ecp(j)` false is the C helper returning NULL: an element with no
        ! ECP block is normal, not an error.
        call parse_ecp_for_element(arg(3), unique(j), shell_list(j), has_ecp(j))
    end do

    ! Atoms of an element with no ECP are simply not ECP centres.
    num_active = 0
    do ia = 1, nat
        bi = unique_index(xyz%symbols(ia))
        if (has_ecp(bi)) num_active = num_active + 1
    end do
    write(*,'(A,I0)') "  ECP atoms: ", num_active

    ! Map active ECP centre -> atom index (0-based, as cuEST expects) and
    ! active ECP centre -> unique element.
    allocate(ecp_indices(num_active), ecp_map(num_active))
    k = 0
    do ia = 1, nat
        bi = unique_index(xyz%symbols(ia))
        if (has_ecp(bi)) then
            k = k + 1
            ecp_indices(k) = int(ia - 1, c_int64_t)
            ecp_map(k) = int(bi, c_int64_t)
        end if
    end do

    ! ---- 6. ECP shells -----------------------------------------------------
    allocate(packs(n_unique))
    call cuest_check(cuestParametersCreate(CUEST_ECPSHELL_PARAMETERS, shell_par), &
                     "ParametersCreate(ECP shell)")

    do j = 1, n_unique
        if (.not. has_ecp(j)) cycle                 ! C: if (!shellList[i]) continue;

        n_sh = shell_list(j)%n_shells - 1_c_int64_t
        allocate(packs(j)%shells(n_sh))

        ! The first parsed shell is the local ("top") shell.
        l  = shell_list(j)%shell_types(1)
        np = shell_list(j)%num_primitives(1)
        call make_ecp_shell(l, np, shell_list(j)%ns(1:np), &
                            shell_list(j)%coefficients(1:np), &
                            shell_list(j)%exponents(1:np), packs(j)%top)

        do k = 1, int(n_sh)
            off = shell_list(j)%primitive_offsets(k+1)      ! 0-based
            l   = shell_list(j)%shell_types(k+1)
            np  = shell_list(j)%num_primitives(k+1)
            call make_ecp_shell(l, np, shell_list(j)%ns(off+1:off+np), &
                                shell_list(j)%coefficients(off+1:off+np), &
                                shell_list(j)%exponents(off+1:off+np), &
                                packs(j)%shells(k))
        end do
    end do

    call cuest_check(cuestParametersDestroy(CUEST_ECPSHELL_PARAMETERS, shell_par), &
                     "ParametersDestroy(ECP shell)")

    ! ---- 7. ECP atoms ------------------------------------------------------
    allocate(ecp_atoms(num_active))
    ecp_atoms = c_null_ptr
    call cuest_check(cuestParametersCreate(CUEST_ECPATOM_PARAMETERS, atom_par), &
                     "ParametersCreate(ECP atom)")

    do k = 1, int(num_active)
        j = int(ecp_map(k))
        nelec = shell_list(j)%n_elec
        n_sh  = shell_list(j)%n_shells - 1_c_int64_t
        call cuest_check(cuestECPAtomCreate(handle, nelec, n_sh, &
                         packs(j)%shells, packs(j)%top, atom_par, &
                         ecp_atoms(k)), "cuestECPAtomCreate")
    end do

    ! The atoms own their shells now, so the shell handles can go.
    do j = 1, n_unique
        if (.not. has_ecp(j)) cycle
        ist = cuestECPShellDestroy(packs(j)%top)
        do k = 1, size(packs(j)%shells)
            ist = cuestECPShellDestroy(packs(j)%shells(k))
        end do
        deallocate(packs(j)%shells)
    end do
    deallocate(packs)

    do j = 1, n_unique
        call free_ecp_shell_set(shell_list(j))
    end do
    deallocate(shell_list, has_ecp, unique, ecp_map)

    call cuest_check(cuestParametersDestroy(CUEST_ECPATOM_PARAMETERS, atom_par), &
                     "ParametersDestroy(ECP atom)")

    ! ---- 8. ECP integral plan (host coordinates enter here) ----------------
    call cuest_check(cuestParametersCreate(CUEST_ECPINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(ECP plan)")
    call cuest_check(cuestECPIntPlanCreateWorkspaceQuery(handle, basis, &
                     c_loc(xyz%xyz_cpu), num_active, ecp_indices, ecp_atoms, &
                     plan_par, d_persist, d_temp, plan), &
                     "ECPIntPlanCreateWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestECPIntPlanCreate(handle, basis, c_loc(xyz%xyz_cpu), &
                     num_active, ecp_indices, ecp_atoms, plan_par, &
                     ws_plan, ws_tmp, plan), "cuestECPIntPlanCreate")
    deallocate(ecp_indices)

    do k = 1, int(num_active)
        ist = cuestECPAtomDestroy(ecp_atoms(k))
    end do
    deallocate(ecp_atoms)

    call cuest_check(cuestParametersDestroy(CUEST_ECPINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(ECP plan)")
    call ws_free(ws_tmp)

    ! ---- 9. compute the ECP matrix -----------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    write(*,'(A,I0)') "  nao      : ", nao

    d_ecp = dev_alloc(nao*nao)
    allocate(h_mat(nao*nao))

    call cuest_check(cuestParametersCreate(CUEST_ECPCOMPUTE_PARAMETERS, comp_par), &
                     "ParametersCreate(ECP compute)")

    var_buf%hostBufferSizeInBytes   = 0_c_size_t
    var_buf%deviceBufferSizeInBytes = VARIABLE_DEVICE_BYTES

    call cuest_check(cuestECPComputeWorkspaceQuery(handle, plan, comp_par, &
                     var_buf, d_temp, d_ecp), "ECPComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestECPCompute(handle, plan, comp_par, var_buf, ws_tmp, &
                     d_ecp), "cuestECPCompute")
    call cuest_check(cuestParametersDestroy(CUEST_ECPCOMPUTE_PARAMETERS, comp_par), &
                     "ParametersDestroy(ECP compute)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 10. report ---------------------------------------------------------
    write(*,'(A)') ""
    call dev_to_host(h_mat, d_ecp, nao*nao)
    call matrix_report("ECP (effective core potential)", h_mat, nao)

    ! ---- 11. teardown -------------------------------------------------------
    deallocate(h_mat)
    call ws_free(ws_tmp)
    call dev_free(d_ecp)

    ist = cuestECPIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    !> Index of an element symbol in the unique list (1-based).
    integer function unique_index(sym) result(idx)
        character(len=2), intent(in) :: sym
        integer :: m
        idx = 1
        do m = 1, n_unique
            if (sym == unique(m)) then
                idx = m
                return
            end if
        end do
    end function unique_index

    !> Wrapper that gives the coefficient/exponent slices the TARGET attribute
    !  C_LOC requires; array sections cannot be passed to C_LOC directly.
    !  These are HOST pointers -- the ECP definition comes from the parser.
    subroutine make_ecp_shell(ll, nprim, radial_powers, coef, expo, shell)
        integer(c_int64_t), intent(in) :: ll, nprim
        integer(c_int64_t), intent(in) :: radial_powers(:)
        real(c_double),     intent(in), target :: coef(:), expo(:)
        type(c_ptr),        intent(inout) :: shell
        call cuest_check(cuestECPShellCreate(handle, ll, nprim, radial_powers, &
                         c_loc(coef), c_loc(expo), shell_par, shell), &
                         "cuestECPShellCreate")
    end subroutine make_ecp_shell

end program ecp_integrals
