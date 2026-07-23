! ============================================================================
!  ecp_atom.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    ecp_atom/main.c
!
!  Builds one cuestECPAtom_t per atom of a molecule that carries an effective
!  core potential. The ECP definitions are read from a Gaussian94 file with the
!  ECP parser helper, one set per unique element; elements with no ECP entry in
!  the file are skipped, exactly as the C sample skips a NULL shell list.
!
!  Structure follows the C sample call for call:
!    handle -> unique elements -> parse ECP per element -> active-atom map
!           -> ECP shells (top + rest) per element -> cuestECPAtomCreate
!           -> cuestQuery
!
!  The "no ECP for this element" case: the C helper returns NULL and the sample
!  tests the pointer (`if (!shellList[i]) continue;`). The Fortran parser cannot
!  return a null derived type, so it reports the same thing through its `found`
!  argument, and this port tests `found` at exactly the same three places the C
!  tests the pointer.
!
!  Difference from the C sample: the C prints the attributes in a form nothing
!  can parse, so every number is additionally emitted as an array/scalar report
!  section. The oracle emits the identical sections.
!
!  Usage:  ./ecp_atom <xyz_file> <ecp_gbs_file>
! ============================================================================
program ecp_atom
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuest_sample_utils, only: cuest_check, scalar_report, array_report, &
                                  arg, require_args
    use xyz_parser
    use ecp_parser
    implicit none

    !> One element's cuEST shell handles: the top shell plus the rest.
    type :: shell_pack_t
        type(c_ptr) :: top = c_null_ptr
        type(c_ptr), allocatable :: shells(:)
    end type shell_pack_t

    type(parsed_xyz_t), target :: xyz

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr
    type(c_ptr) :: ecp_shell_par = c_null_ptr
    type(c_ptr) :: ecp_atom_par = c_null_ptr

    character(len=2), allocatable :: unique_symbols(:)
    type(ecp_shell_set_t), allocatable :: shell_list(:)
    logical, allocatable :: has_ecp(:)
    type(shell_pack_t), allocatable :: pack_(:)
    integer, allocatable :: ecp_map(:)
    type(c_ptr), allocatable :: ecp_atoms(:)

    real(c_double), allocatable :: rep_max_l(:), rep_nelec(:)

    integer(c_int64_t) :: max_l = 0, nelec = 0
    integer(c_int64_t) :: n_shells_wo_top, l, np, off
    integer :: n_unique, num_active_ecp, nat, i, j, k, basis_index, ecp
    integer(c_int) :: ist
    logical :: is_new

    call require_args(2, "<xyz_file> <ecp_file>")

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    nat = int(xyz%num_atoms)

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. the unique elements --------------------------------------------
    allocate(unique_symbols(nat))
    n_unique = 0
    do i = 1, nat
        is_new = .true.
        do j = 1, n_unique
            if (xyz%symbols(i) == unique_symbols(j)) then
                is_new = .false.
                exit
            end if
        end do
        if (is_new) then
            n_unique = n_unique + 1
            unique_symbols(n_unique) = xyz%symbols(i)
        end if
    end do

    ! ---- 4. the ECP definition of each unique element ----------------------
    !  A missing element is not an error: the C helper returns NULL for it and
    !  the sample simply skips that element. `found` carries the same meaning.
    allocate(shell_list(n_unique), has_ecp(n_unique))
    do i = 1, n_unique
        call parse_ecp_for_element(arg(2), trim(unique_symbols(i)), &
                                   shell_list(i), has_ecp(i))
    end do

    ! ---- 5. how many atoms actually carry an ECP ---------------------------
    num_active_ecp = 0
    do i = 1, nat
        do j = 1, n_unique
            if (xyz%symbols(i) == unique_symbols(j)) then
                basis_index = j
                if (has_ecp(basis_index)) num_active_ecp = num_active_ecp + 1
                exit
            end if
        end do
    end do

    ! ---- 6. map from active ECP atom to element ----------------------------
    allocate(ecp_map(max(num_active_ecp, 1)))
    ecp_map = 0
    ecp = 0
    do i = 1, nat
        do j = 1, n_unique
            if (xyz%symbols(i) == unique_symbols(j)) then
                basis_index = j
                if (has_ecp(basis_index)) then
                    ecp = ecp + 1
                    ecp_map(ecp) = basis_index
                end if
                exit
            end if
        end do
    end do

    ! The geometry and the symbol table are not needed past this point.
    call free_parsed_xyz(xyz)
    deallocate(unique_symbols)

    ! ---- 7. ECP shells, per element that has an ECP ------------------------
    allocate(pack_(n_unique))

    call cuest_check(cuestParametersCreate(CUEST_ECPSHELL_PARAMETERS, ecp_shell_par), &
                     "ParametersCreate(ECP shell)")

    do i = 1, n_unique
        if (.not. has_ecp(i)) cycle

        n_shells_wo_top = shell_list(i)%n_shells - 1_c_int64_t
        allocate(pack_(i)%shells(n_shells_wo_top))
        pack_(i)%shells = c_null_ptr

        ! The top (local) shell is shell 1 of the parsed set, at offset 0.
        l  = shell_list(i)%shell_types(1)
        np = shell_list(i)%num_primitives(1)
        call create_ecp_shell(l, np, shell_list(i)%ns(1:np), &
                              shell_list(i)%coefficients(1:np), &
                              shell_list(i)%exponents(1:np), pack_(i)%top)

        do k = 1, int(n_shells_wo_top)
            off = shell_list(i)%primitive_offsets(k+1)     ! 0-based, as in C
            l   = shell_list(i)%shell_types(k+1)
            np  = shell_list(i)%num_primitives(k+1)
            call create_ecp_shell(l, np, shell_list(i)%ns(off+1 : off+np), &
                                  shell_list(i)%coefficients(off+1 : off+np), &
                                  shell_list(i)%exponents(off+1 : off+np), &
                                  pack_(i)%shells(k))
        end do
    end do

    call cuest_check(cuestParametersDestroy(CUEST_ECPSHELL_PARAMETERS, ecp_shell_par), &
                     "ParametersDestroy(ECP shell)")

    ! ---- 8. one ECP atom per active atom -----------------------------------
    allocate(ecp_atoms(max(num_active_ecp, 1)))
    ecp_atoms = c_null_ptr

    call cuest_check(cuestParametersCreate(CUEST_ECPATOM_PARAMETERS, ecp_atom_par), &
                     "ParametersCreate(ECP atom)")

    do i = 1, num_active_ecp
        j = ecp_map(i)
        call cuest_check(cuestECPAtomCreate(handle, shell_list(j)%n_elec, &
                         shell_list(j)%n_shells - 1_c_int64_t, &
                         pack_(j)%shells, pack_(j)%top, ecp_atom_par, &
                         ecp_atoms(i)), "cuestECPAtomCreate")
    end do

    call cuest_check(cuestParametersDestroy(CUEST_ECPATOM_PARAMETERS, ecp_atom_par), &
                     "ParametersDestroy(ECP atom)")

    ! ---- 9. the shells and the parsed data can go now ----------------------
    do i = 1, n_unique
        if (.not. has_ecp(i)) cycle
        ist = cuestECPShellDestroy(pack_(i)%top)
        do k = 1, size(pack_(i)%shells)
            ist = cuestECPShellDestroy(pack_(i)%shells(k))
        end do
        deallocate(pack_(i)%shells)
    end do
    deallocate(pack_)

    do i = 1, n_unique
        call free_ecp_shell_set(shell_list(i))
    end do
    deallocate(shell_list, has_ecp, ecp_map)

    ! ---- 10. query and destroy each ECP atom -------------------------------
    allocate(rep_max_l(max(num_active_ecp, 1)), rep_nelec(max(num_active_ecp, 1)))
    rep_max_l = 0.0d0
    rep_nelec = 0.0d0

    do i = 1, num_active_ecp
        call cuest_check(cuest_query_i64(handle, CUEST_ECPATOM, ecp_atoms(i), &
                         CUEST_ECPATOM_MAX_L, max_l), "query ECPATOM_MAX_L")
        call cuest_check(cuest_query_i64(handle, CUEST_ECPATOM, ecp_atoms(i), &
                         CUEST_ECPATOM_NUM_ELECTRON, nelec), "query ECPATOM_NUM_ELECTRON")

        write(*,'(A)') "ECP Atom from handle:"
        write(*,'(A,I6)') "max_L      = ", max_l
        write(*,'(A,I6)') "nelec      = ", nelec
        write(*,'(A)') ""

        rep_max_l(i) = real(max_l, c_double)
        rep_nelec(i) = real(nelec, c_double)

        ist = cuestECPAtomDestroy(ecp_atoms(i))
    end do
    deallocate(ecp_atoms)

    ! ---- 11. report --------------------------------------------------------
    call scalar_report("num unique elements", real(n_unique, c_double))
    call scalar_report("num active ECP atoms", real(num_active_ecp, c_double))
    if (num_active_ecp > 0) then
        call array_report("ECP atom max_L", rep_max_l, &
                          int(num_active_ecp, c_int64_t))
        call array_report("ECP atom nelec", rep_nelec, &
                          int(num_active_ecp, c_int64_t))
    end if
    deallocate(rep_max_l, rep_nelec)

    ! ---- 12. teardown ------------------------------------------------------
    ist = cuestDestroy(handle)

contains

    !> Wrapper that gives the coefficient/exponent slices the TARGET attribute
    !  C_LOC requires; array sections cannot be passed to C_LOC directly.
    subroutine create_ecp_shell(l_in, np_in, ns, coef, expo, shell)
        integer(c_int64_t), intent(in) :: l_in, np_in
        integer(c_int64_t), intent(in) :: ns(:)
        real(c_double), intent(in), target :: coef(:), expo(:)
        type(c_ptr), intent(inout) :: shell
        call cuest_check(cuestECPShellCreate(handle, l_in, np_in, ns, &
                         c_loc(coef), c_loc(expo), ecp_shell_par, shell), &
                         "cuestECPShellCreate")
    end subroutine create_ecp_shell

end program ecp_atom
