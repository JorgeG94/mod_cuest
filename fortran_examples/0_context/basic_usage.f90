! ============================================================================
!  basic_usage.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/0_context/basic_usage/main.c
!
!  The most basic use of the cuEST handle: create a handle parameters object,
!  inspect the defaults it was given, reconfigure the JIT compiler settings,
!  create the handle, and tear everything down again.
!
!  Structure follows the C sample call for call:
!    parameters -> query defaults -> configure JIT -> query back -> handle
!
!  Difference from the C sample: the queried attribute values are additionally
!  emitted as `scalar` report sections, so compare.py can check them against
!  the C oracle. The JIT cache directory is a string and is printed plainly.
!
!  Usage:  ./basic_usage
! ============================================================================
program basic_usage
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_param_get_i64, cuest_param_set_i32, &
                             cuest_param_set_str
    use cuest_sample_utils, only: cuest_check, scalar_report
    implicit none

    !> cuEST allocates a queried string attribute with malloc; the caller frees
    !  it with C's native free(), exactly as the C sample does.
    interface
        subroutine c_free(p) bind(C, name="free")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine c_free
    end interface

    !> The cuEST handle.
    type(c_ptr) :: handle = c_null_ptr

    !> The parameters for cuEST handle creation.
    type(c_ptr) :: handle_parameters = c_null_ptr

    integer(c_int64_t) :: max_gauss_hermite = 0
    integer(c_int64_t) :: max_l_solid_harmonic = 0
    integer(c_int64_t) :: max_rys_points = 0

    character(*),       parameter :: JIT_CACHE_DIR = "/tmp/cuest-jit-cache"
    integer(c_int32_t), parameter :: JIT_COMPILE_THREADS = 8_c_int32_t

    type(c_ptr), target :: queried_cache_dir = c_null_ptr

    ! ---- 1. handle parameters, with the library's defaults -----------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersCreate(handle)")

    ! ---- 2. check the defaults cuestParametersCreate installed -------------
    call cuest_check(cuest_param_get_i64(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_MAX_GAUSS_HERMITE, &
                     max_gauss_hermite), "ParametersQuery(MAX_GAUSS_HERMITE)")
    call cuest_check(cuest_param_get_i64(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_MAX_L_SOLID_HARMONIC, &
                     max_l_solid_harmonic), "ParametersQuery(MAX_L_SOLID_HARMONIC)")
    call cuest_check(cuest_param_get_i64(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_MAX_RYS, &
                     max_rys_points), "ParametersQuery(MAX_RYS)")

    write(*,'(A,I0)') "Maximum number of Gauss-Hermite quadrature points: ", &
        max_gauss_hermite
    write(*,'(A,I0)') &
        "Maximum angular momentum (L) solid harmonic transformation: ", &
        max_l_solid_harmonic
    if (max_rys_points == 0) then
        write(*,'(A,I0,A)') "Maximum number of Rys quadrature points: ", &
            max_rys_points, " (zero requests the largest available table)"
    else
        write(*,'(A,I0,A)') "Maximum number of Rys quadrature points: ", &
            max_rys_points, "  "
    end if

    ! ---- 3. configure the JIT compiler -------------------------------------
    ! CUEST_HANDLE_PARAMETERS_JIT_CACHE_DIR is the directory compiled kernels
    ! are cached in (empty, the default, means ~/.cuest_cache/...); it must be
    ! a trusted, per-user, non-world-writable path. JIT_COMPILE_THREADS is the
    ! number of parallel JIT-compile workers (>= 1; default 16). Both take
    ! effect at cuestCreate.
    call cuest_check(cuest_param_set_str(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_JIT_CACHE_DIR, &
                     JIT_CACHE_DIR), "ParametersConfigure(JIT_CACHE_DIR)")
    call cuest_check(cuest_param_set_i32(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_JIT_COMPILE_THREADS, &
                     JIT_COMPILE_THREADS), "ParametersConfigure(JIT_COMPILE_THREADS)")

    ! ---- 4. query the string attribute back --------------------------------
    ! cuEST allocates the returned string; the caller owns it.
    call cuest_check(cuestParametersQuery(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_JIT_CACHE_DIR, &
                     c_loc(queried_cache_dir), c_sizeof(queried_cache_dir)), &
                     "ParametersQuery(JIT_CACHE_DIR)")
    write(*,'(A,A)') "JIT cache directory: ", c_string(queried_cache_dir)
    call c_free(queried_cache_dir)
    queried_cache_dir = c_null_ptr

    ! ---- 5. report ---------------------------------------------------------
    ! Everything below this point is a report section; compare.py starts
    ! parsing here, so no further "label : number" lines may be printed.
    call scalar_report("max Gauss-Hermite points", real(max_gauss_hermite, c_double))
    call scalar_report("max L solid harmonic", real(max_l_solid_harmonic, c_double))
    call scalar_report("max Rys points", real(max_rys_points, c_double))
    call scalar_report("JIT compile threads", real(JIT_COMPILE_THREADS, c_double))

    ! ---- 6. create the handle ----------------------------------------------
    ! This creates the CUDA stream, cuBLAS handle and cuSolver handle that the
    ! cuEST handle owns and destroys with itself.
    call cuest_check(cuestCreate(handle_parameters, handle), "cuestCreate")

    ! The handle parameters may go as soon as the handle exists.
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersDestroy(handle)")

    ! This is where the cuEST handle would normally be used.

    ! ---- 7. teardown -------------------------------------------------------
    call cuest_check(cuestDestroy(handle), "cuestDestroy")

contains

    !> A NUL-terminated C string as a Fortran allocatable string.
    function c_string(p) result(s)
        type(c_ptr), intent(in) :: p
        character(len=:), allocatable :: s
        character(kind=c_char), pointer :: buf(:)
        integer, parameter :: MAXLEN = 4096
        integer :: i, n
        if (.not. c_associated(p)) then
            s = "(null)"
            return
        end if
        call c_f_pointer(p, buf, [MAXLEN])
        n = 0
        do i = 1, MAXLEN
            if (buf(i) == c_null_char) exit
            n = i
        end do
        allocate(character(len=n) :: s)
        do i = 1, n
            s(i:i) = buf(i)
        end do
    end function c_string

end program basic_usage
