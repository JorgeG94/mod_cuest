! ============================================================================
!  test_parsers.f90 -- validates the ported common/ helpers.
!
!  Exercises xyz_parser, gbs_parser and the shell normalization WITHOUT
!  creating a cuEST handle, so it runs on any CUDA GPU -- including Volta,
!  where cuEST itself refuses to initialise. That makes it the one part of the
!  sample port that can be checked without a queue submission.
!
!  Usage:  ./test_parsers <xyz_file> <gbs_file>
!  Expected for h2o.xyz + def2-svp.gbs: 3 atoms, 12 shells, 24 AOs.
! ============================================================================
program test_parsers
    use, intrinsic :: iso_c_binding
    use xyz_parser
    use gbs_parser
    use ao_shells, only: normalized_coefficients
    use cuest_sample_utils, only: arg, require_args
    implicit none

    type(parsed_xyz_t), target :: xyz
    type(atom_basis_t) :: b
    character(len=2), allocatable :: unique(:)
    integer :: failures, n_unique, i, j, ish, nao_total, nsh_total
    integer(c_int64_t) :: l, np
    real(c_double), allocatable :: cn(:)
    logical :: is_new

    failures = 0
    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A)') "=========================================================="
    write(*,'(A)') " parser self-test"
    write(*,'(A)') "=========================================================="

    ! ---- XYZ ---------------------------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    write(*,'(A)') "-- xyz"
    write(*,'(A,I0)') "   atoms: ", xyz%num_atoms
    do i = 1, int(xyz%num_atoms)
        write(*,'(4X,A,3(1X,F12.8),A,F6.1)') xyz%symbols(i), &
            xyz%xyz_cpu(3*(i-1)+1), xyz%xyz_cpu(3*(i-1)+2), &
            xyz%xyz_cpu(3*(i-1)+3), "   charge ", xyz%charges_cpu(i)
    end do
    call ok(c_associated(xyz%xyz_gpu), "coordinates mirrored to device")
    call ok(c_associated(xyz%charges_gpu), "charges mirrored to device")
    ! cuEST convention: charges carry the electron sign, so they are -Z.
    call ok(all(xyz%charges_cpu < 0.0d0), "charges are negative (-Z convention)")

    ! ---- unique elements ---------------------------------------------------
    allocate(unique(int(xyz%num_atoms)))
    n_unique = 0
    do i = 1, int(xyz%num_atoms)
        is_new = .true.
        do j = 1, n_unique
            if (xyz%symbols(i) == unique(j)) is_new = .false.
        end do
        if (is_new) then
            n_unique = n_unique + 1
            unique(n_unique) = xyz%symbols(i)
        end if
    end do
    write(*,'(A,I0)') "   unique elements: ", n_unique

    ! ---- GBS ---------------------------------------------------------------
    write(*,'(A)') "-- gbs"
    nao_total = 0
    nsh_total = 0
    do j = 1, n_unique
        call parse_gbs_for_element(arg(2), unique(j), b)
        write(*,'(4X,A,A,I0,A)') unique(j), ": ", b%n_shells, " shells"
        do ish = 1, int(b%n_shells)
            l  = b%shell_types(ish)
            np = b%num_primitives(ish)
            write(*,'(6X,A,I0,A,I0,A,ES13.6,A,ES13.6)') "L=", l, " nprim=", np, &
                "  first exp=", b%exponents(b%primitive_offsets(ish)+1), &
                "  coef=",      b%coefficients(b%primitive_offsets(ish)+1)
        end do
        ! spherical harmonics: 2L+1 functions per shell
        do i = 1, int(xyz%num_atoms)
            if (xyz%symbols(i) == unique(j)) then
                nsh_total = nsh_total + int(b%n_shells)
                do ish = 1, int(b%n_shells)
                    nao_total = nao_total + 2*int(b%shell_types(ish)) + 1
                end do
            end if
        end do
        call ok(b%n_shells > 0, "parsed shells for " // unique(j))
        call ok(size(b%exponents) == int(sum(b%num_primitives)), &
                "primitive count consistent for " // unique(j))
        call free_atom_basis(b)
    end do
    write(*,'(A,I0)') "   total shells: ", nsh_total
    write(*,'(A,I0,A)') "   total AOs   : ", nao_total, "  (spherical)"

    ! ---- normalization -----------------------------------------------------
    ! A single uncontracted primitive must normalize to (2a/pi)^(3/4) for L=0.
    write(*,'(A)') "-- normalization"
    allocate(cn(1))
    call normalized_coefficients(0_c_int64_t, 1_c_int64_t, [1.0d0], [1.0d0], &
                                 1.0d0, cn)
    call ok(abs(cn(1) - (2.0d0/3.14159265358979323846d0)**0.75d0) < 1.0d-13, &
            "L=0, a=1 gives (2a/pi)^(3/4)")
    write(*,'(6X,A,ES22.14)') "got      ", cn(1)
    write(*,'(6X,A,ES22.14)') "expected ", (2.0d0/3.14159265358979323846d0)**0.75d0
    call normalized_coefficients(1_c_int64_t, 1_c_int64_t, [0.8d0], [1.0d0], &
                                 1.0d0, cn)
    write(*,'(6X,A,ES22.14)') "L=1, a=0.8 -> ", cn(1)
    deallocate(cn)

    call free_parsed_xyz(xyz)
    deallocate(unique)

    write(*,'(A)') "----------------------------------------------------------"
    if (failures == 0) then
        write(*,'(A)') "ALL PARSER TESTS PASSED"
    else
        write(*,'(A,I0)') "FAILURES: ", failures
        error stop 1
    end if

contains

    subroutine ok(cond, what)
        logical,      intent(in) :: cond
        character(*), intent(in) :: what
        if (cond) then
            write(*,'(A,A)') "  [ ok ] ", what
        else
            write(*,'(A,A)') "  [FAIL] ", what
            failures = failures + 1
        end if
    end subroutine ok

end program test_parsers
