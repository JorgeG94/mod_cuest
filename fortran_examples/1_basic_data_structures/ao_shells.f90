! ============================================================================
!  ao_shells.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    ao_shells/main.c
!
!  Builds three contracted Gaussian AO shells for carbon in def2-SVP (1s, 2p
!  and a d polarisation function) straight from the exponents and contraction
!  coefficients, then queries each shell for its attributes.
!
!  Structure follows the C sample call for call:
!    handle -> AO shell parameters -> 3 x cuestAOShellCreate -> cuestQuery
!
!  Note the coefficients are passed to cuEST exactly as written, without the
!  normalisation helper_ao_shells.h applies -- that is what the C sample does.
!
!  Difference from the C sample: the C prints the attributes but nothing that
!  compare.py can parse, so every queried number is additionally emitted as a
!  scalar report section. The oracle does the same, with the same labels.
!
!  Usage:  ./ao_shells        (no arguments)
! ============================================================================
program ao_shells_sample
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64, cuest_query_i32
    use cuest_sample_utils, only: cuest_check, scalar_report
    implicit none

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par  = c_null_ptr
    type(c_ptr) :: sh_par = c_null_ptr
    type(c_ptr) :: shells(3) = [c_null_ptr, c_null_ptr, c_null_ptr]
    integer(c_int) :: ist
    integer :: is, ia

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t

    !> A carbon 1s shell.
    real(c_double), target :: c_1s_exponents(5) = &
        [1238.4016938d0, 186.29004992d0, 42.251176346d0, &
         11.676557932d0, 3.5930506482d0]
    real(c_double), target :: c_1s_coefficients(5) = &
        [0.0054568832082d0, 0.040638409211d0, 0.18025593888d0, &
         0.46315121755d0, 0.44087173314d0]

    !> A carbon 2p shell.
    real(c_double), target :: c_2p_exponents(3) = &
        [9.4680970621d0, 2.0103545142d0, 0.54771004707d0]
    real(c_double), target :: c_2p_coefficients(3) = &
        [0.038387871728d0, 0.21117025112d0, 0.51328172114d0]

    !> A carbon d polarisation shell.
    real(c_double), target :: c_d_exponents(1) = [0.8d0]
    real(c_double), target :: c_d_coefficients(1) = [1.0d0]

    !> Queried attributes, kept so every one of them can be reported after all
    !  of the sample's own output has been written.
    integer(c_int64_t) :: attr(6,3) = 0_c_int64_t

    character(len=2), parameter :: TAG(3) = [character(len=2) :: "1s", "2p", "d"]
    character(len=16), parameter :: ATTR_NAME(6) = [character(len=16) :: &
        "is_pure", "L", "num_primitives", "num_ao", "num_pure", "num_cart"]
    character(len=32), parameter :: TITLE(3) = [character(len=32) :: &
        "Carbon 1S shell (def2-SVP):", "Carbon 2p shell (def2-SVP):", &
        "Carbon d shell (def2-SVP):"]

    ! ---- 1. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 2. one shared AO shell parameters object --------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOSHELL_PARAMETERS, sh_par), &
                     "ParametersCreate(AO shell)")

    ! ---- 3. the three shells -----------------------------------------------
    call cuest_check(cuestAOShellCreate(handle, IS_PURE, 0_c_int64_t, &
                     5_c_int64_t, c_loc(c_1s_exponents), &
                     c_loc(c_1s_coefficients), sh_par, shells(1)), &
                     "cuestAOShellCreate(C 1s)")

    call cuest_check(cuestAOShellCreate(handle, IS_PURE, 1_c_int64_t, &
                     3_c_int64_t, c_loc(c_2p_exponents), &
                     c_loc(c_2p_coefficients), sh_par, shells(2)), &
                     "cuestAOShellCreate(C 2p)")

    call cuest_check(cuestAOShellCreate(handle, IS_PURE, 2_c_int64_t, &
                     1_c_int64_t, c_loc(c_d_exponents), &
                     c_loc(c_d_coefficients), sh_par, shells(3)), &
                     "cuestAOShellCreate(C d)")

    call cuest_check(cuestParametersDestroy(CUEST_AOSHELL_PARAMETERS, sh_par), &
                     "ParametersDestroy(AO shell)")

    ! ---- 4. query each shell -----------------------------------------------
    do is = 1, 3
        call query_shell(shells(is), attr(:,is))
    end do

    ! ---- 5. the sample's own output ----------------------------------------
    do is = 1, 3
        write(*,'(A)') trim(TITLE(is))
        write(*,'(A)') ""
        if (attr(1,is) /= 0) then
            write(*,'(A)') "Angular momentum:              spherical"
        else
            write(*,'(A)') "Angular momentum:              cartesian"
        end if
        write(*,'(A,I0)') "L:                             ", attr(2,is)
        write(*,'(A,I0)') "Number of primitives:          ", attr(3,is)
        write(*,'(A,I0)') "Number of basis functions:     ", attr(4,is)
        write(*,'(A,I0)') "Number of pure functions:      ", attr(5,is)
        write(*,'(A,I0)') "Number of cartesian functions: ", attr(6,is)
        write(*,'(A)') ""
    end do

    ! ---- 6. report ---------------------------------------------------------
    do is = 1, 3
        do ia = 1, 6
            call scalar_report("C "//trim(TAG(is))//" "//trim(ATTR_NAME(ia)), &
                               real(attr(ia,is), c_double))
        end do
    end do

    ! ---- 7. teardown -------------------------------------------------------
    do is = 1, 3
        ist = cuestAOShellDestroy(shells(is))
    end do
    ist = cuestDestroy(handle)

contains

    !> Pull the six documented AO shell attributes into a(1:6).
    subroutine query_shell(shell, a)
        type(c_ptr),        intent(in)  :: shell
        integer(c_int64_t), intent(out) :: a(6)
        integer(c_int32_t) :: is_pure
        integer(c_int64_t) :: l, nprim, nao, npure, ncart
        call cuest_check(cuest_query_i32(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_IS_PURE, is_pure), "query IS_PURE")
        call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_L, l), "query L")
        call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_NUM_PRIMITIVE, nprim), "query NUM_PRIMITIVE")
        call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_NUM_AO, nao), "query NUM_AO")
        call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_NUM_PURE, npure), "query NUM_PURE")
        call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shell, &
                         CUEST_AOSHELL_NUM_CART, ncart), "query NUM_CART")
        a(1) = int(is_pure, c_int64_t)
        a(2) = l
        a(3) = nprim
        a(4) = nao
        a(5) = npure
        a(6) = ncart
    end subroutine query_shell

end program ao_shells_sample
