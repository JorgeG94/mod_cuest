! ============================================================================
!  xyz_parser.f90 -- Fortran port of common/helper_xyz_parser.h
!
!  Reads an XYZ file, converts coordinates to bohr, maps element symbols to
!  atomic numbers, and mirrors the coordinates and charges to the device
!  (cuestPotentialCompute wants DEVICE pointers for both).
!
!  Charge convention, copied from the C helper: cuEST's potential evaluation
!  does not assume the electron charge, so charges are stored as -Z, not +Z.
! ============================================================================
module xyz_parser
    use, intrinsic :: iso_c_binding
    use cuda_runtime
    use cuda_helpers, only: cuda_check
    implicit none
    private

    public :: parsed_xyz_t, parse_xyz_file, free_parsed_xyz
    public :: symbol_to_atomic_number, ANGSTROM_TO_BOHR

    !> The C helper uses 1.0 / 0.52917720859; keep the identical constant so
    !  coordinates agree with the C samples bit for bit.
    real(c_double), parameter :: ANGSTROM_TO_BOHR = 1.0d0 / 0.52917720859d0

    type :: parsed_xyz_t
        integer(c_int64_t) :: num_atoms = 0
        real(c_double), allocatable :: xyz_cpu(:)      !< 3*num_atoms, bohr
        real(c_double), allocatable :: charges_cpu(:)  !< num_atoms, = -Z
        type(c_ptr) :: xyz_gpu     = c_null_ptr
        type(c_ptr) :: charges_gpu = c_null_ptr
        character(len=2), allocatable :: symbols(:)    !< uppercase
    end type parsed_xyz_t

    character(len=2), parameter :: ELEMENTS(0:118) = [character(len=2) :: &
        "X",  "H",  "HE", "LI", "BE", "B",  "C",  "N",  "O",  "F",  "NE", &
        "NA", "MG", "AL", "SI", "P",  "S",  "CL", "AR", "K",  "CA", &
        "SC", "TI", "V",  "CR", "MN", "FE", "CO", "NI", "CU", "ZN", &
        "GA", "GE", "AS", "SE", "BR", "KR", "RB", "SR", "Y",  "ZR", &
        "NB", "MO", "TC", "RU", "RH", "PD", "AG", "CD", "IN", "SN", &
        "SB", "TE", "I",  "XE", "CS", "BA", "LA", "CE", "PR", "ND", &
        "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM", "YB", &
        "LU", "HF", "TA", "W",  "RE", "OS", "IR", "PT", "AU", "HG", &
        "TL", "PB", "BI", "PO", "AT", "RN", "FR", "RA", "AC", "TH", &
        "PA", "U",  "NP", "PU", "AM", "CM", "BK", "CF", "ES", "FM", &
        "MD", "NO", "LR", "RF", "DB", "SG", "BH", "HS", "MT", "DS", &
        "RG", "CN", "NH", "FL", "MC", "LV", "TS", "OG"]

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

    integer function symbol_to_atomic_number(symbol) result(z)
        character(*), intent(in) :: symbol
        character(len=2) :: s
        integer :: i
        s = upcase(adjustl(symbol))
        do i = 0, 118
            if (s == ELEMENTS(i)) then
                z = i
                return
            end if
        end do
        write(*,'(A,A,A)') "Unknown atomic symbol '", trim(symbol), "'"
        error stop 1
    end function symbol_to_atomic_number

    !> Parse an XYZ file and mirror coordinates/charges to the device.
    subroutine parse_xyz_file(path, to_bohr, x)
        character(*),        intent(in)  :: path
        real(c_double),      intent(in)  :: to_bohr
        type(parsed_xyz_t), intent(out), target :: x

        integer :: u, ios, i, n
        character(len=512) :: line
        character(len=32)  :: sym
        real(c_double) :: cx, cy, cz

        open(newunit=u, file=path, status="old", action="read", iostat=ios)
        if (ios /= 0) then
            write(*,'(A,A)') "Unable to open XYZ file: ", trim(path)
            error stop 1
        end if

        read(u, '(A)', iostat=ios) line
        if (ios /= 0) then
            write(*,'(A)') "Failed to read number of atoms"
            error stop 1
        end if
        read(line, *, iostat=ios) n
        if (ios /= 0 .or. n <= 0) then
            write(*,'(A)') "Failed to parse number of atoms"
            error stop 1
        end if
        read(u, '(A)', iostat=ios) line          ! comment line, ignored

        x%num_atoms = int(n, c_int64_t)
        allocate(x%xyz_cpu(3*n), x%charges_cpu(n), x%symbols(n))

        do i = 1, n
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) then
                write(*,'(A,I0)') "Failed to read atom line ", i
                error stop 1
            end if
            read(line, *, iostat=ios) sym, cx, cy, cz
            if (ios /= 0) then
                write(*,'(A,I0)') "Failed to parse atom line ", i
                error stop 1
            end if
            x%xyz_cpu(3*(i-1) + 1) = cx * to_bohr
            x%xyz_cpu(3*(i-1) + 2) = cy * to_bohr
            x%xyz_cpu(3*(i-1) + 3) = cz * to_bohr
            x%symbols(i) = upcase(adjustl(sym))
            ! see the header comment: -Z, not +Z
            x%charges_cpu(i) = -1.0d0 * real(symbol_to_atomic_number(sym), c_double)
        end do
        close(u)

        ! Mirror to the device: cuestPotentialCompute takes device pointers.
        call cuda_check(cudaMalloc(x%xyz_gpu, int(3*n, c_size_t) * 8_c_size_t), &
                        "cudaMalloc(xyz)")
        call cuda_check(cudaMalloc(x%charges_gpu, int(n, c_size_t) * 8_c_size_t), &
                        "cudaMalloc(charges)")
        call cuda_check(cudaMemcpy(x%xyz_gpu, c_loc(x%xyz_cpu), &
                        int(3*n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                        "cudaMemcpy(xyz H2D)")
        call cuda_check(cudaMemcpy(x%charges_gpu, c_loc(x%charges_cpu), &
                        int(n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                        "cudaMemcpy(charges H2D)")
    end subroutine parse_xyz_file

    subroutine free_parsed_xyz(x)
        type(parsed_xyz_t), intent(inout) :: x
        integer(c_int) :: ist
        if (c_associated(x%xyz_gpu))     ist = cudaFree(x%xyz_gpu)
        if (c_associated(x%charges_gpu)) ist = cudaFree(x%charges_gpu)
        x%xyz_gpu     = c_null_ptr
        x%charges_gpu = c_null_ptr
        if (allocated(x%xyz_cpu))     deallocate(x%xyz_cpu)
        if (allocated(x%charges_cpu)) deallocate(x%charges_cpu)
        if (allocated(x%symbols))     deallocate(x%symbols)
        x%num_atoms = 0
    end subroutine free_parsed_xyz

end module xyz_parser
