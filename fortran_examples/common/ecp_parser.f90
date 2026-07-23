! ============================================================================
!  ecp_parser.f90 -- Fortran port of common/helper_ecp_parser.h
!
!  Parses the effective-core-potential definitions of a Gaussian94-format file
!  (as downloaded from the Basis Set Exchange in "Gaussian" or "Psi4" format)
!  and returns the ECP shell definitions for one element.
!
!  The ECP block for element X starts with a header line
!
!      X-ECP     <max_l>     <n_elec>
!
!  and is followed by one "<label> potential" line per shell, each carrying a
!  primitive count and that many "<N> <exponent> <coefficient>" lines. The
!  first shell listed is the local ("top") shell; callers pass shell 1 (index 0
!  in C) to cuestECPShellCreate as the top shell and the remaining n_shells-1
!  shells as the ordinary ECP shells. The block ends at the next element's
!  "X 0" line, or at end of file.
!
!  Same restrictions as the C helper:
!    * SP / SPD combined shells are NOT handled. Use "Uncontract SPDF" when
!      downloading, or split them into separate S and P blocks.
!    * lines beginning with '!' are comments.
!    * the ECP definitions may follow the basis set in the same file or live in
!      a standalone file; the basis section is simply ignored.
!
!  Two structural notes where Fortran differs from the C original:
!    * the C helper converts 'D' exponents to 'e' before strtod; Fortran's
!      list-directed READ accepts 1.23D-02 natively, so no fixup is needed.
!    * primitive_offsets is kept 0-based, as in C, so the arithmetic matches
!      the C helper line for line. Callers add 1 when slicing.
!
!  Unlike parse_gbs_for_element, a missing element is NOT an error: light atoms
!  legitimately have no ECP, and the C helper returns NULL for them. That is
!  reported through the `found` argument, which callers must test before using
!  the result (see how the C samples skip `if (!shellList[i]) continue;`).
! ============================================================================
module ecp_parser
    use, intrinsic :: iso_c_binding
    use gbs_parser, only: angular_momentum_to_l
    implicit none
    private

    public :: ecp_shell_set_t, parse_ecp_for_element, free_ecp_shell_set

    type :: ecp_shell_set_t
        integer(c_int64_t) :: n_shells = 0                       !< incl. top shell
        integer(c_int64_t) :: n_elec = 0                         !< core electrons replaced
        integer(c_int64_t) :: max_l = 0                          !< from the X-ECP header
        integer(c_int64_t), allocatable :: shell_types(:)        !< L per shell
        integer(c_int64_t), allocatable :: num_primitives(:)
        integer(c_int64_t), allocatable :: primitive_offsets(:)  !< 0-based
        integer(c_int64_t), allocatable :: ns(:)                 !< radial powers, packed
        real(c_double),     allocatable :: exponents(:)          !< packed
        real(c_double),     allocatable :: coefficients(:)       !< packed
    end type ecp_shell_set_t

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

    !> Parse `ecp_path` and return the ECP definition for `element`.
    !
    !  Two passes, mirroring the C helper: the first counts shells and
    !  primitives so the arrays can be sized, the second fills them.
    !
    !  `found` is .false. (and `s` left empty) when the file holds no ECP for
    !  `element` -- the Fortran equivalent of the C helper's NULL return.
    subroutine parse_ecp_for_element(ecp_path, element, s, found)
        character(*),          intent(in)  :: ecp_path
        character(*),          intent(in)  :: element
        type(ecp_shell_set_t), intent(out) :: s
        logical,               intent(out) :: found

        integer :: u, ios, nwords, nprim, nskip
        integer :: n_shells, n_prims_total, ishell, iprim, nprim_to_parse
        integer :: max_l, n_elec, radial_n
        logical :: in_block
        character(len=512) :: line
        character(len=8)   :: want
        character(len=64)  :: tok1, tok2
        real(c_double) :: e, c

        found = .false.

        ! The C helper builds "<ELEMENT>-ECP" and matches the block header
        ! against it; a symbol is one or two characters.
        if (len_trim(adjustl(element)) < 1 .or. len_trim(adjustl(element)) > 2) then
            write(*,'(A,A,A)') "Incorrect element length: '", trim(element), "'"
            error stop 1
        end if
        want = upcase(trim(adjustl(element)))//"-ECP"

        ! ---- pass 1: count -------------------------------------------------
        open(newunit=u, file=ecp_path, status="old", action="read", iostat=ios)
        if (ios /= 0) then
            write(*,'(A,A)') "Unable to open ECP file: ", trim(ecp_path)
            error stop 1
        end if

        n_shells = 0
        n_prims_total = 0
        max_l = 0
        n_elec = 0
        in_block = .false.
        nskip = 0
        do
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) exit
            if (is_skippable(line)) cycle

            ! Skip the primitives of the shell just counted.
            if (nskip > 0) then
                nskip = nskip - 1
                cycle
            end if

            nwords = count_words(line)
            if (nwords < 1 .or. nwords > 3) cycle

            ! Potential label, e.g. "s-f potential". A second word containing
            ! '0' is the next element's "X 0" line, so the block is over.
            if (in_block .and. nwords == 2) then
                read(line, *, iostat=ios) tok1, tok2
                if (ios /= 0) then
                    write(*,'(A)') "ECP parse error reading a potential label"
                    error stop 1
                end if
                if (index(tok2, "0") > 0) exit
                cycle
            end if

            ! Primitive count for the shell just labelled.
            if (in_block .and. nwords == 1) then
                read(line, *, iostat=ios) nprim
                if (ios /= 0) then
                    write(*,'(A)') "ECP parse error reading a primitive count"
                    error stop 1
                end if
                nskip = nprim
                n_shells = n_shells + 1
                n_prims_total = n_prims_total + nprim
                cycle
            end if

            ! First line of an ECP block: "<X>-ECP <max_l> <n_elec>".
            if (.not. in_block .and. nwords == 3) then
                if (upcase(first_token(line)) == want) then
                    in_block = .true.
                    read(line, *, iostat=ios) tok1, max_l, n_elec
                    if (ios /= 0) then
                        write(*,'(A)') "ECP parse error reading the block header"
                        error stop 1
                    end if
                end if
            end if
        end do

        ! No ECP for this element: mirror the C helper's NULL return.
        if (.not. in_block) then
            close(u)
            return
        end if

        s%n_shells = int(n_shells, c_int64_t)
        s%n_elec = int(n_elec, c_int64_t)
        s%max_l = int(max_l, c_int64_t)
        allocate(s%shell_types(n_shells), s%num_primitives(n_shells), &
                 s%primitive_offsets(n_shells))
        allocate(s%ns(n_prims_total), s%exponents(n_prims_total), &
                 s%coefficients(n_prims_total))

        ! ---- pass 2: fill --------------------------------------------------
        rewind(u)
        ishell = 0          ! shells completed == 0-based index of the next one
        iprim = 0
        in_block = .false.
        nprim_to_parse = 0
        do
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) exit
            if (is_skippable(line)) cycle

            if (nprim_to_parse > 0 .and. in_block) then
                ! Fortran reads 1.23D-02 directly; no D->e fixup needed.
                read(line, *, iostat=ios) radial_n, e, c
                if (ios /= 0) then
                    write(*,'(A)') "ECP parse error reading a primitive"
                    error stop 1
                end if
                iprim = iprim + 1
                s%ns(iprim) = int(radial_n, c_int64_t)
                s%exponents(iprim) = e
                s%coefficients(iprim) = c
                nprim_to_parse = nprim_to_parse - 1
                cycle
            end if

            nwords = count_words(line)
            if (nwords < 1 .or. nwords > 3) cycle

            if (in_block .and. nwords == 2) then
                read(line, *, iostat=ios) tok1, tok2
                if (ios /= 0) then
                    write(*,'(A)') "ECP parse error reading a potential label"
                    error stop 1
                end if
                if (index(tok2, "0") > 0) exit
                ! The label's leading character is the shell's L; it is stored
                ! at the slot the next primitive-count line will claim.
                if (ishell + 1 > n_shells) then
                    write(*,'(A)') "ECP parse error: more shells than counted"
                    error stop 1
                end if
                s%shell_types(ishell+1) = angular_momentum_to_l(tok1(1:1))
                cycle
            end if

            if (in_block .and. nwords == 1) then
                read(line, *, iostat=ios) nprim
                if (ios /= 0) then
                    write(*,'(A)') "ECP parse error reading a primitive count"
                    error stop 1
                end if
                ishell = ishell + 1
                s%num_primitives(ishell) = int(nprim, c_int64_t)
                if (ishell == 1) then
                    s%primitive_offsets(ishell) = 0_c_int64_t
                else
                    s%primitive_offsets(ishell) = s%primitive_offsets(ishell-1) &
                                                + s%num_primitives(ishell-1)
                end if
                nprim_to_parse = nprim
                cycle
            end if

            if (.not. in_block .and. nwords == 3) then
                if (upcase(first_token(line)) == want) in_block = .true.
            end if
        end do
        close(u)

        if (ishell /= n_shells .or. iprim /= n_prims_total) then
            write(*,'(A)') "ECP parse error: two passes disagree"
            error stop 1
        end if

        found = .true.
    end subroutine parse_ecp_for_element

    subroutine free_ecp_shell_set(s)
        type(ecp_shell_set_t), intent(inout) :: s
        if (allocated(s%shell_types))       deallocate(s%shell_types)
        if (allocated(s%num_primitives))    deallocate(s%num_primitives)
        if (allocated(s%primitive_offsets)) deallocate(s%primitive_offsets)
        if (allocated(s%ns))                deallocate(s%ns)
        if (allocated(s%exponents))         deallocate(s%exponents)
        if (allocated(s%coefficients))      deallocate(s%coefficients)
        s%n_shells = 0
        s%n_elec = 0
        s%max_l = 0
    end subroutine free_ecp_shell_set

end module ecp_parser
