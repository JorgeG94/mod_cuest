! ============================================================================
!  ecp_shells.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    ecp_shells/main.c
!
!  Builds the four def2-SVP-ecp effective-core-potential shells of iodine from
!  their radial powers, coefficients and exponents: the local "top" shell (the
!  f potential, L = max_L) and the three s-f, p-f and d-f shells. Each shell is
!  queried for its angular momentum and primitive count.
!
!  Structure follows the C sample call for call:
!    handle -> ECP shell parameters -> 4 x cuestECPShellCreate -> cuestQuery
!
!  Difference from the C sample: the C prints the attributes in a form nothing
!  can parse, so each queried number is additionally emitted as a scalar report
!  section. The oracle emits the identical sections.
!
!  Usage:  ./ecp_shells        (no arguments)
! ============================================================================
program ecp_shells
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuest_sample_utils, only: cuest_check, scalar_report
    implicit none

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par  = c_null_ptr
    type(c_ptr) :: ecp_par = c_null_ptr
    type(c_ptr) :: top_shell = c_null_ptr
    type(c_ptr) :: ecp_shells_arr(3) = [c_null_ptr, c_null_ptr, c_null_ptr]

    ! ---- f potential: the top ECP shell ------------------------------------
    integer(c_int64_t), target :: radial_powers_f(4) = &
        [2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t]
    real(c_double), target :: coefficients_f(4) = &
        [-21.84204000d0, -28.46819100d0, -0.24371300d0, -0.32080400d0]
    real(c_double), target :: exponents_f(4) = &
        [19.45860900d0, 19.34926000d0, 4.82376700d0, 4.88431500d0]

    ! ---- s-f potential -----------------------------------------------------
    integer(c_int64_t), target :: radial_powers_s(7) = &
        [2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t, &
         2_c_int64_t, 2_c_int64_t, 2_c_int64_t]
    real(c_double), target :: coefficients_s(7) = &
        [49.99429300d0, 281.02531700d0, 61.57332600d0, 21.84204000d0, &
         28.46819100d0, 0.24371300d0, 0.32080400d0]
    real(c_double), target :: exponents_s(7) = &
        [40.01583500d0, 17.42974700d0, 9.00548400d0, 19.45860900d0, &
         19.34926000d0, 4.82376700d0, 4.88431500d0]

    ! ---- p-f potential -----------------------------------------------------
    integer(c_int64_t), target :: radial_powers_p(8) = &
        [2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t, &
         2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t]
    real(c_double), target :: coefficients_p(8) = &
        [67.44284100d0, 134.88113700d0, 14.67505100d0, 29.37566600d0, &
         21.84204000d0, 28.46819100d0, 0.24371300d0, 0.32080400d0]
    real(c_double), target :: exponents_p(8) = &
        [15.35546600d0, 14.97183300d0, 8.96016400d0, 8.25909600d0, &
         19.45860900d0, 19.34926000d0, 4.82376700d0, 4.88431500d0]

    ! ---- d-f potential -----------------------------------------------------
    integer(c_int64_t), target :: radial_powers_d(10) = &
        [2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t, &
         2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t, 2_c_int64_t]
    real(c_double), target :: coefficients_d(10) = &
        [35.43952900d0, 53.17605700d0, 9.06719500d0, 13.20693700d0, &
         0.08933500d0, 0.05238000d0, 21.84204000d0, 28.46819100d0, &
         0.24371300d0, 0.32080400d0]
    real(c_double), target :: exponents_d(10) = &
        [15.06890800d0, 14.55532200d0, 6.71864700d0, 6.45639300d0, &
         1.19177900d0, 1.29115700d0, 19.45860900d0, 19.34926000d0, &
         4.82376700d0, 4.88431500d0]

    !> Queried attributes, kept so all of them can be reported after the
    !  sample's own output has been written. Row 1 is L, row 2 is nprimitive;
    !  column 1 is the top shell, columns 2..4 the ordinary shells.
    integer(c_int64_t) :: attr(2,4) = 0_c_int64_t

    character(len=16), parameter :: LABEL(4) = [character(len=16) :: &
        "ECP top shell", "ECP shell 1", "ECP shell 2", "ECP shell 3"]
    character(len=16), parameter :: TITLE(4) = [character(len=16) :: &
        "ECP Top shell:", "ECP 1 shell:", "ECP 2 shell:", "ECP 3 shell:"]

    integer(c_int) :: ist
    integer :: i

    ! ---- 1. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 2. one shared ECP shell parameters object -------------------------
    call cuest_check(cuestParametersCreate(CUEST_ECPSHELL_PARAMETERS, ecp_par), &
                     "ParametersCreate(ECP shell)")

    ! ---- 3. the four shells ------------------------------------------------
    call cuest_check(cuestECPShellCreate(handle, 3_c_int64_t, 4_c_int64_t, &
                     radial_powers_f, c_loc(coefficients_f), &
                     c_loc(exponents_f), ecp_par, top_shell), &
                     "cuestECPShellCreate(f, top)")

    call cuest_check(cuestECPShellCreate(handle, 0_c_int64_t, 7_c_int64_t, &
                     radial_powers_s, c_loc(coefficients_s), &
                     c_loc(exponents_s), ecp_par, ecp_shells_arr(1)), &
                     "cuestECPShellCreate(s-f)")

    call cuest_check(cuestECPShellCreate(handle, 1_c_int64_t, 8_c_int64_t, &
                     radial_powers_p, c_loc(coefficients_p), &
                     c_loc(exponents_p), ecp_par, ecp_shells_arr(2)), &
                     "cuestECPShellCreate(p-f)")

    call cuest_check(cuestECPShellCreate(handle, 2_c_int64_t, 10_c_int64_t, &
                     radial_powers_d, c_loc(coefficients_d), &
                     c_loc(exponents_d), ecp_par, ecp_shells_arr(3)), &
                     "cuestECPShellCreate(d-f)")

    call cuest_check(cuestParametersDestroy(CUEST_ECPSHELL_PARAMETERS, ecp_par), &
                     "ParametersDestroy(ECP shell)")

    ! ---- 4. query every shell ----------------------------------------------
    call query_ecp_shell(top_shell, attr(:,1))
    do i = 1, 3
        call query_ecp_shell(ecp_shells_arr(i), attr(:,i+1))
    end do

    ! ---- 5. the sample's own output ----------------------------------------
    do i = 1, 4
        write(*,'(A)') trim(TITLE(i))
        write(*,'(A)') ""
        write(*,'(A,I0)') "L:                             ", attr(1,i)
        write(*,'(A,I0)') "Number of primitives:          ", attr(2,i)
        write(*,'(A)') ""
    end do

    ! ---- 6. report ---------------------------------------------------------
    do i = 1, 4
        call scalar_report(trim(LABEL(i))//" L", real(attr(1,i), c_double))
        call scalar_report(trim(LABEL(i))//" num_primitives", &
                           real(attr(2,i), c_double))
    end do

    ! ---- 7. teardown -------------------------------------------------------
    ist = cuestECPShellDestroy(top_shell)
    do i = 1, 3
        ist = cuestECPShellDestroy(ecp_shells_arr(i))
    end do
    ist = cuestDestroy(handle)

contains

    !> Pull the two documented ECP shell attributes into a(1:2).
    subroutine query_ecp_shell(shell, a)
        type(c_ptr),        intent(in)  :: shell
        integer(c_int64_t), intent(out) :: a(2)
        call cuest_check(cuest_query_i64(handle, CUEST_ECPSHELL, shell, &
                         CUEST_ECPSHELL_L, a(1)), "query ECPSHELL_L")
        call cuest_check(cuest_query_i64(handle, CUEST_ECPSHELL, shell, &
                         CUEST_ECPSHELL_NUM_PRIMITIVE, a(2)), &
                         "query ECPSHELL_NUM_PRIMITIVE")
    end subroutine query_ecp_shell

end program ecp_shells
