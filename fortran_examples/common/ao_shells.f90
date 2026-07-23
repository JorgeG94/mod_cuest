! ============================================================================
!  ao_shells.f90 -- Fortran port of common/helper_ao_shells.h and
!  common/helper_shell_normalization.h
!
!  Given a parsed XYZ file and a GBS path, builds the array of cuestAOShell_t
!  handles (and the per-atom shell counts) needed to create a cuEST AO basis.
!
!  Coefficients are normalized exactly as the C helper does, so the resulting
!  basis is identical to the one the C samples construct.
! ============================================================================
module ao_shells
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_sample_utils, only: cuest_check
    use xyz_parser, only: parsed_xyz_t
    use gbs_parser, only: atom_basis_t, parse_gbs_for_element, free_atom_basis
    implicit none
    private

    public :: ao_shell_data_t, form_ao_shells, free_ao_shell_data
    public :: normalized_coefficients

    type :: ao_shell_data_t
        integer(c_int64_t) :: num_atoms = 0
        integer(c_int64_t) :: num_shells_total = 0
        integer(c_int64_t), allocatable :: num_shells_per_atom(:)
        type(c_ptr),        allocatable :: shells(:)
    end type ao_shell_data_t

    real(c_double), parameter :: PI = 3.14159265358979323846d0

contains

    !> Normalized contraction coefficients for one shell.
    !
    !  Direct port of computeNormalizedCoefficients(). Two stages: a
    !  per-primitive normalization, then an overall factor Q that normalizes
    !  the contracted function to `normalization`.
    subroutine normalized_coefficients(l, nprim, expo, coef, normalization, out)
        integer(c_int64_t), intent(in)  :: l, nprim
        real(c_double),     intent(in)  :: expo(:), coef(:), normalization
        real(c_double),     intent(out) :: out(:)
        real(c_double) :: pi32, twol, dfact, q
        integer :: i, j, k

        if (any(expo(1:int(nprim)) <= 0.0d0)) then
            write(*,'(A)') "shell normalization: exponents must be positive"
            error stop 1
        end if
        if (l >= 9_c_int64_t) then
            write(*,'(A)') "shell normalization: L >= 9 is not supported"
            error stop 1
        end if
        if (normalization <= 0.0d0) then
            write(*,'(A)') "shell normalization: normalization must be > 0"
            error stop 1
        end if

        pi32 = PI**1.5d0
        twol = 2.0d0**real(l, c_double)

        dfact = 1.0d0
        do k = 1, int(l)
            dfact = dfact * real(2*k - 1, c_double)
        end do

        do i = 1, int(nprim)
            out(i) = sqrt(twol / (pi32 * dfact) &
                     * (2.0d0 * expo(i))**(real(l, c_double) + 1.5d0)) * coef(i)
        end do

        q = 0.0d0
        do i = 1, int(nprim)
            do j = 1, int(nprim)
                q = q + (sqrt(4.0d0 * expo(i) * expo(j)) &
                        / (expo(i) + expo(j)))**(real(l, c_double) + 1.5d0) &
                        * coef(i) * coef(j)
            end do
        end do
        q = q**(-0.5d0) * sqrt(normalization)

        do i = 1, int(nprim)
            out(i) = out(i) * q
        end do
    end subroutine normalized_coefficients

    !> Build the cuEST AO shell array for a molecule.
    subroutine form_ao_shells(handle, x, gbs_file, is_pure, sd)
        type(c_ptr),           intent(in)  :: handle
        type(parsed_xyz_t),    intent(in)  :: x
        character(*),          intent(in)  :: gbs_file
        integer(c_int32_t),    intent(in)  :: is_pure
        type(ao_shell_data_t), intent(out) :: sd

        character(len=2), allocatable :: unique(:)
        type(atom_basis_t), allocatable :: basis_list(:)
        integer :: n_unique, ia, j, ish, count, bi, nat
        integer(c_int64_t) :: l, np, off
        real(c_double), allocatable, target :: cnorm(:)
        type(c_ptr) :: sh_par
        logical :: is_new

        nat = int(x%num_atoms)

        ! ---- unique elements ----------------------------------------------
        allocate(unique(nat))
        n_unique = 0
        do ia = 1, nat
            is_new = .true.
            do j = 1, n_unique
                if (x%symbols(ia) == unique(j)) then
                    is_new = .false.
                    exit
                end if
            end do
            if (is_new) then
                n_unique = n_unique + 1
                unique(n_unique) = x%symbols(ia)
            end if
        end do

        allocate(basis_list(n_unique))
        do j = 1, n_unique
            call parse_gbs_for_element(gbs_file, unique(j), basis_list(j))
        end do

        ! ---- shells per atom ----------------------------------------------
        sd%num_atoms = x%num_atoms
        allocate(sd%num_shells_per_atom(nat))
        sd%num_shells_total = 0
        do ia = 1, nat
            bi = element_index(x%symbols(ia), unique, n_unique)
            sd%num_shells_per_atom(ia) = basis_list(bi)%n_shells
            sd%num_shells_total = sd%num_shells_total + basis_list(bi)%n_shells
        end do

        allocate(sd%shells(sd%num_shells_total))
        sd%shells = c_null_ptr

        ! ---- create the shells --------------------------------------------
        sh_par = c_null_ptr
        call cuest_check(cuestParametersCreate(CUEST_AOSHELL_PARAMETERS, sh_par), &
                         "ParametersCreate(AO shell)")

        count = 0
        do ia = 1, nat
            bi = element_index(x%symbols(ia), unique, n_unique)
            do ish = 1, int(sd%num_shells_per_atom(ia))
                l   = basis_list(bi)%shell_types(ish)
                np  = basis_list(bi)%num_primitives(ish)
                off = basis_list(bi)%primitive_offsets(ish)     ! 0-based

                allocate(cnorm(np))
                call normalized_coefficients(l, np, &
                     basis_list(bi)%exponents(off+1 : off+np), &
                     basis_list(bi)%coefficients(off+1 : off+np), &
                     1.0d0, cnorm)

                count = count + 1
                call create_shell(handle, is_pure, l, np, &
                     basis_list(bi)%exponents(off+1 : off+np), cnorm, &
                     sh_par, sd%shells(count))

                deallocate(cnorm)
            end do
        end do

        call cuest_check(cuestParametersDestroy(CUEST_AOSHELL_PARAMETERS, sh_par), &
                         "ParametersDestroy(AO shell)")

        do j = 1, n_unique
            call free_atom_basis(basis_list(j))
        end do
        deallocate(basis_list, unique)
    end subroutine form_ao_shells

    !> Wrapper that gives the exponent/coefficient slices the TARGET attribute
    !  C_LOC requires. Array sections cannot be passed to C_LOC directly.
    subroutine create_shell(handle, is_pure, l, np, expo, coef, sh_par, shell)
        type(c_ptr),        intent(in)    :: handle, sh_par
        integer(c_int32_t), intent(in)    :: is_pure
        integer(c_int64_t), intent(in)    :: l, np
        real(c_double),     intent(in), target :: expo(:), coef(:)
        type(c_ptr),        intent(inout) :: shell
        call cuest_check(cuestAOShellCreate(handle, is_pure, l, np, &
                         c_loc(expo), c_loc(coef), sh_par, shell), &
                         "cuestAOShellCreate")
    end subroutine create_shell

    pure integer function element_index(sym, unique, n) result(k)
        character(len=2), intent(in) :: sym, unique(:)
        integer,          intent(in) :: n
        integer :: j
        k = 1
        do j = 1, n
            if (sym == unique(j)) then
                k = j
                return
            end if
        end do
    end function element_index

    subroutine free_ao_shell_data(sd)
        type(ao_shell_data_t), intent(inout) :: sd
        integer(c_int) :: ist
        integer :: i
        if (allocated(sd%shells)) then
            do i = 1, size(sd%shells)
                if (c_associated(sd%shells(i))) ist = cuestAOShellDestroy(sd%shells(i))
            end do
            deallocate(sd%shells)
        end if
        if (allocated(sd%num_shells_per_atom)) deallocate(sd%num_shells_per_atom)
        sd%num_atoms = 0
        sd%num_shells_total = 0
    end subroutine free_ao_shell_data

end module ao_shells
