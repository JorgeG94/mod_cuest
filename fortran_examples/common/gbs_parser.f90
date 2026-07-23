! ============================================================================
!  gbs_parser.f90 -- Fortran port of common/helper_gbs_parser.h
!
!  Parses a Gaussian94-format basis set file (as downloaded from the Basis Set
!  Exchange) and returns the shell definitions for one element.
!
!  Same restrictions as the C helper:
!    * SP / SPD combined shells are NOT handled. Use "Uncontract SPDF" when
!      downloading, or split them into separate S and P blocks.
!    * lines beginning with '!' are comments; ECP definitions after the basis
!      are not parsed.
!
!  Two structural notes where Fortran differs from the C original:
!    * the C helper converts 'D' exponents to 'e' before strtod; Fortran's
!      list-directed READ accepts 1.23D-02 natively, so no fixup is needed.
!    * primitive_offsets is kept 0-based, as in C, so the arithmetic matches
!      the C helper line for line. Callers add 1 when slicing.
! ============================================================================
module gbs_parser
    use, intrinsic :: iso_c_binding
    implicit none
    private

    public :: atom_basis_t, parse_gbs_for_element, free_atom_basis
    public :: angular_momentum_to_l

    type :: atom_basis_t
        integer(c_int64_t) :: n_shells = 0
        integer(c_int64_t), allocatable :: shell_types(:)        !< L per shell
        integer(c_int64_t), allocatable :: num_primitives(:)
        integer(c_int64_t), allocatable :: primitive_offsets(:)  !< 0-based
        real(c_double),     allocatable :: exponents(:)          !< packed
        real(c_double),     allocatable :: coefficients(:)       !< packed
    end type atom_basis_t

    character(len=1), parameter :: SHELL_TYPES(0:20) = [character(len=1) :: &
        'S','P','D','F','G','H','I','K', &
        'L','M','N','O','Q','R','T','U','V','W','X','Y','Z']

contains

    pure function upcase(s) result(u)
        character(*), intent(in) :: s
        character(len=len(s)) :: u
        integer :: i, c
        do i = 1, len(s)
            c = iachar(s(i:i))
            if (c >= iachar('a') .and. c <= iachar('z')) then
                u(i:i) = achar(c - 32)
            else
                u(i:i) = s(i:i)
            end if
        end do
    end function upcase

    integer(c_int64_t) function angular_momentum_to_l(am) result(l)
        character, intent(in) :: am
        character(len=1) :: a
        integer :: i
        a = upcase(am)
        do i = 0, 20
            if (SHELL_TYPES(i) == a) then
                l = int(i, c_int64_t)
                return
            end if
        end do
        write(*,'(A,A,A)') "Unknown angular momentum symbol '", am, "'"
        error stop 1
    end function angular_momentum_to_l

    !> Number of whitespace-separated words in a string.
    pure integer function count_words(s) result(n)
        character(*), intent(in) :: s
        integer :: i
        logical :: in_word
        n = 0
        in_word = .false.
        do i = 1, len_trim(s)
            if (s(i:i) == ' ' .or. s(i:i) == achar(9)) then
                in_word = .false.
            else if (.not. in_word) then
                in_word = .true.
                n = n + 1
            end if
        end do
    end function count_words

    !> First whitespace-separated token of a line ('' if the line is blank).
    pure function first_token(s) result(t)
        character(*), intent(in) :: s
        character(len=len(s)) :: t
        integer :: i, j
        t = ''
        i = 1
        do while (i <= len_trim(s))
            if (s(i:i) /= ' ' .and. s(i:i) /= achar(9)) exit
            i = i + 1
        end do
        if (i > len_trim(s)) return
        j = i
        do while (j <= len_trim(s))
            if (s(j:j) == ' ' .or. s(j:j) == achar(9)) exit
            j = j + 1
        end do
        t = s(i:j-1)
    end function first_token

    !> True for a line that should be skipped outright (blank or a comment).
    pure logical function is_skippable(line) result(skip)
        character(*), intent(in) :: line
        character(len=len(line)) :: t
        t = adjustl(line)
        skip = (len_trim(t) == 0) .or. (t(1:1) == '!')
    end function is_skippable

    !> Parse `gbs_path` and return the basis definition for `element`.
    !
    !  Two passes, mirroring the C helper: the first counts shells and
    !  primitives so the arrays can be sized, the second fills them.
    subroutine parse_gbs_for_element(gbs_path, element, b)
        character(*),        intent(in)  :: gbs_path
        character(*),        intent(in)  :: element
        type(atom_basis_t),  intent(out) :: b

        integer :: u, ios, nwords, nprim, nskip
        integer :: n_shells, n_prims_total, ishell, iprim, nprim_to_parse
        logical :: in_block, found_block
        character(len=512) :: line
        character(len=2)   :: want, block_atom
        character(len=64)  :: tok
        real(c_double) :: e, c

        want = upcase(adjustl(element))

        ! ---- pass 1: count -------------------------------------------------
        open(newunit=u, file=gbs_path, status="old", action="read", iostat=ios)
        if (ios /= 0) then
            write(*,'(A,A)') "Unable to open GBS file: ", trim(gbs_path)
            error stop 1
        end if

        n_shells = 0
        n_prims_total = 0
        in_block = .false.
        found_block = .false.
        nskip = 0
        do
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) exit
            if (is_skippable(line)) cycle
            if (nskip > 0) then
                nskip = nskip - 1
                cycle
            end if
            if (index(line, "****") > 0) then
                if (found_block) exit
                in_block = .false.
                cycle
            end if
            nwords = count_words(line)
            if (nwords /= 2 .and. nwords /= 3) cycle
            if (.not. in_block) then
                block_atom = upcase(first_token(line))
                if (block_atom == want) found_block = .true.
                in_block = .true.
                cycle
            end if
            if (.not. found_block) cycle
            read(line, *, iostat=ios) tok, nprim
            if (ios /= 0) then
                write(*,'(A)') "GBS parse error reading shell header"
                error stop 1
            end if
            nskip = nprim
            n_shells = n_shells + 1
            n_prims_total = n_prims_total + nprim
        end do

        if (.not. found_block) then
            close(u)
            write(*,'(A,A,A,A)') "Failed to find element ", trim(element), &
                " in ", trim(gbs_path)
            error stop 1
        end if

        b%n_shells = int(n_shells, c_int64_t)
        allocate(b%shell_types(n_shells), b%num_primitives(n_shells), &
                 b%primitive_offsets(n_shells))
        allocate(b%exponents(n_prims_total), b%coefficients(n_prims_total))

        ! ---- pass 2: fill --------------------------------------------------
        rewind(u)
        ishell = 0
        iprim = 0
        in_block = .false.
        found_block = .false.
        nprim_to_parse = 0
        do
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) exit
            if (is_skippable(line)) cycle

            if (nprim_to_parse > 0 .and. found_block) then
                ! Fortran reads 1.23D-02 directly; no D->e fixup needed.
                read(line, *, iostat=ios) e, c
                if (ios /= 0) then
                    write(*,'(A)') "GBS parse error reading a primitive"
                    error stop 1
                end if
                iprim = iprim + 1
                b%exponents(iprim) = e
                b%coefficients(iprim) = c
                nprim_to_parse = nprim_to_parse - 1
                cycle
            end if

            if (index(line, "****") > 0) then
                if (found_block) exit
                in_block = .false.
                cycle
            end if
            nwords = count_words(line)
            if (nwords /= 2 .and. nwords /= 3) cycle
            if (.not. in_block) then
                block_atom = upcase(first_token(line))
                if (block_atom == want) found_block = .true.
                in_block = .true.
                cycle
            end if
            if (.not. found_block) cycle

            read(line, *, iostat=ios) tok, nprim
            if (ios /= 0) then
                write(*,'(A)') "GBS parse error reading shell header"
                error stop 1
            end if
            ishell = ishell + 1
            b%shell_types(ishell) = angular_momentum_to_l(tok(1:1))
            b%num_primitives(ishell) = int(nprim, c_int64_t)
            if (ishell == 1) then
                b%primitive_offsets(ishell) = 0_c_int64_t
            else
                b%primitive_offsets(ishell) = b%primitive_offsets(ishell-1) &
                                            + b%num_primitives(ishell-1)
            end if
            nprim_to_parse = nprim
        end do
        close(u)

        if (ishell /= n_shells .or. iprim /= n_prims_total) then
            write(*,'(A)') "GBS parse error: two passes disagree"
            error stop 1
        end if
    end subroutine parse_gbs_for_element

    subroutine free_atom_basis(b)
        type(atom_basis_t), intent(inout) :: b
        if (allocated(b%shell_types))       deallocate(b%shell_types)
        if (allocated(b%num_primitives))    deallocate(b%num_primitives)
        if (allocated(b%primitive_offsets)) deallocate(b%primitive_offsets)
        if (allocated(b%exponents))         deallocate(b%exponents)
        if (allocated(b%coefficients))      deallocate(b%coefficients)
        b%n_shells = 0
    end subroutine free_atom_basis

end module gbs_parser
