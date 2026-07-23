! ============================================================================
!  pcm_helper.f90 -- Fortran port of common/helper_pcm.h
!
!  Utilities for building PCM cavity parameters from molecular geometry:
!
!    * scaled (1.2x) Bondi atomic radii in bohr, keyed by element symbol
!    * the York-Karplus quadrature zeta for a Lebedev grid of n angular points
!
!  Both tables and both failure modes mirror the C helper exactly: an element
!  outside the Bondi table (H..LR, Z = 1..103) or an angular point count
!  outside the York-Karplus table is a fatal error, not a sentinel value.
! ============================================================================
module pcm_helper
    use, intrinsic :: iso_c_binding
    implicit none
    private

    public :: symbol_to_scaled_bondi_radius_bohr, pcm_angular_points_to_zeta

    !> Number of entries in the Bondi table (H through LR).
    integer, parameter :: NUM_BONDI = 103

    !> Uppercase element symbols, in the order of the C bondi_symbols_ table.
    character(len=2), parameter :: BONDI_SYMBOLS(NUM_BONDI) = [character(len=2) :: &
        "H",  "HE", "LI", "BE", "B",  "C",  "N",  "O",  "F",  "NE", &
        "NA", "MG", "AL", "SI", "P",  "S",  "CL", "AR", "K",  "CA", &
        "SC", "TI", "V",  "CR", "MN", "FE", "CO", "NI", "CU", "ZN", &
        "GA", "GE", "AS", "SE", "BR", "KR", "RB", "SR", "Y",  "ZR", &
        "NB", "MO", "TC", "RU", "RH", "PD", "AG", "CD", "IN", "SN", &
        "SB", "TE", "I",  "XE", "CS", "BA", "LA", "CE", "PR", "ND", &
        "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM", "YB", &
        "LU", "HF", "TA", "W",  "RE", "OS", "IR", "PT", "AU", "HG", &
        "TL", "PB", "BI", "PO", "AT", "RN", "FR", "RA", "AC", "TH", &
        "PA", "U",  "NP", "PU", "AM", "CM", "BK", "CF", "ES", "FM", &
        "MD", "NO", "LR"]

    !> Unscaled Bondi radii in angstrom.  Truhlar et al., J. Phys. Chem. A,
    !  113, 5806-5812 (2009) Table 12 and the CRC Handbook, 95th ed., pp. 9-49.
    real(c_double), parameter :: BONDI_RADII_ANG(NUM_BONDI) = [ &
        1.10d0, 1.40d0, 1.81d0, 1.53d0, 1.92d0, 1.70d0, 1.55d0, 1.52d0, 1.47d0, 1.54d0, &
        2.27d0, 1.73d0, 1.84d0, 2.10d0, 1.80d0, 1.80d0, 1.75d0, 1.88d0, 2.75d0, 2.31d0, &
        2.15d0, 2.11d0, 2.07d0, 2.06d0, 2.05d0, 2.04d0, 2.00d0, 1.97d0, 1.96d0, 2.01d0, &
        1.87d0, 2.11d0, 1.85d0, 1.90d0, 1.83d0, 2.02d0, 3.03d0, 2.49d0, 2.32d0, 2.23d0, &
        2.18d0, 2.17d0, 2.16d0, 2.13d0, 2.10d0, 2.10d0, 2.11d0, 2.18d0, 1.93d0, 2.17d0, &
        2.06d0, 2.06d0, 1.98d0, 2.16d0, 3.43d0, 2.68d0, 2.43d0, 2.42d0, 2.40d0, 2.39d0, &
        2.38d0, 2.36d0, 2.35d0, 2.34d0, 2.33d0, 2.31d0, 2.30d0, 2.29d0, 2.27d0, 2.26d0, &
        2.24d0, 2.23d0, 2.22d0, 2.18d0, 2.16d0, 2.16d0, 2.13d0, 2.13d0, 2.14d0, 2.23d0, &
        1.96d0, 2.02d0, 2.07d0, 1.97d0, 2.02d0, 2.20d0, 3.48d0, 2.83d0, 2.47d0, 2.45d0, &
        2.43d0, 2.41d0, 2.39d0, 2.43d0, 2.44d0, 2.45d0, 2.44d0, 2.45d0, 2.45d0, 2.45d0, &
        2.46d0, 2.46d0, 2.46d0]

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

    !> 1.2 x the Bondi radius of `symbol`, in bohr.
    !
    !  The C helper is documented as taking an already-uppercase symbol (the XYZ
    !  parser upcases before storing); we upcase here too so the function is
    !  usable with a literal such as "Ne".  The arithmetic keeps the C order,
    !  1.2 * r_ang / 0.52917720859, so the result agrees bit for bit.
    function symbol_to_scaled_bondi_radius_bohr(symbol) result(radius)
        character(*), intent(in) :: symbol
        real(c_double) :: radius
        character(len=2) :: s
        integer :: i

        s = upcase(adjustl(symbol))
        do i = 1, NUM_BONDI
            if (s == BONDI_SYMBOLS(i)) then
                radius = 1.2d0 * BONDI_RADII_ANG(i) / 0.52917720859d0
                return
            end if
        end do

        write(*,'(A,A)') "No Bondi radius defined for element ", trim(adjustl(symbol))
        error stop 1
    end function symbol_to_scaled_bondi_radius_bohr

    !> York-Karplus zeta exponent for a Lebedev grid of `n` angular points.
    !  J. Phys. Chem. A, 103, 11060-11079 (1999), Table 1.
    function pcm_angular_points_to_zeta(n) result(zeta)
        integer(c_int64_t), intent(in) :: n
        real(c_double) :: zeta

        select case (n)
        case (14_c_int64_t);   zeta = 4.865d0
        case (26_c_int64_t);   zeta = 4.855d0
        case (50_c_int64_t);   zeta = 4.893d0
        case (110_c_int64_t);  zeta = 4.901d0
        case (194_c_int64_t);  zeta = 4.903d0
        case (302_c_int64_t);  zeta = 4.905d0
        case (434_c_int64_t);  zeta = 4.906d0
        case (590_c_int64_t);  zeta = 4.905d0
        case (770_c_int64_t);  zeta = 4.899d0
        case (974_c_int64_t);  zeta = 4.907d0
        case (1202_c_int64_t); zeta = 4.907d0
        case default
            write(*,'(A,I0,A)') "No York-Karplus zeta for ", n, " angular points"
            error stop 1
        end select
    end function pcm_angular_points_to_zeta

end module pcm_helper
