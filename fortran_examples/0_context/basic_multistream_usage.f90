! ============================================================================
!  basic_multistream_usage.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/0_context/
!    basic_multistream_usage/main.c
!
!  Two cuEST handles on one GPU, each with its own CUDA stream, so cuEST calls
!  can overlap on a single device.
!
!  Structure follows the C sample call for call:
!    one parameters object -> two cuestCreate calls -> two cuestDestroy calls
!
!  Difference from the C sample: it creates the handles and exits without
!  printing anything. This port reports the number of handles that came back
!  live and whether they are distinct, so the result can be checked.
!
!  Usage:  ./basic_multistream_usage
! ============================================================================
program basic_multistream_usage
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_sample_utils, only: cuest_check, scalar_report
    implicit none

    !> The cuEST handles.
    type(c_ptr) :: handle(2) = c_null_ptr

    !> The parameters for cuEST handle creation.
    type(c_ptr) :: handle_parameters = c_null_ptr

    real(c_double) :: num_created, num_distinct

    ! ---- 1. handle parameters, with the library's defaults -----------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersCreate(handle)")

    ! ---- 2. two handles, two streams ---------------------------------------
    ! Each cuestCreate initialises a unique CUDA stream for its handle; the
    ! same parameters object serves both calls.
    call cuest_check(cuestCreate(handle_parameters, handle(1)), "cuestCreate(1)")
    call cuest_check(cuestCreate(handle_parameters, handle(2)), "cuestCreate(2)")

    ! The handle parameters may go as soon as the handles exist.
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersDestroy(handle)")

    ! This is where the handles would normally be used, best from two threads.

    ! ---- 3. report ---------------------------------------------------------
    num_created = 0.0d0
    if (c_associated(handle(1))) num_created = num_created + 1.0d0
    if (c_associated(handle(2))) num_created = num_created + 1.0d0

    num_distinct = 0.0d0
    if (.not. c_associated(handle(1), handle(2))) num_distinct = 1.0d0

    call scalar_report("cuEST handles created", num_created)
    call scalar_report("distinct handle pointers", num_distinct)

    ! ---- 4. teardown -------------------------------------------------------
    call cuest_check(cuestDestroy(handle(1)), "cuestDestroy(1)")
    call cuest_check(cuestDestroy(handle(2)), "cuestDestroy(2)")

end program basic_multistream_usage
