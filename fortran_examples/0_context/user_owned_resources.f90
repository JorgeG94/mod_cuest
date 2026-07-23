! ============================================================================
!  user_owned_resources.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/0_context/
!    user_owned_resources/main.c
!
!  Creates a CUDA stream, a cuBLAS handle and a cuSolver handle, hands them to
!  cuestCreate through the handle parameters, and keeps ownership: destroying
!  the cuEST handle does not destroy them.
!
!  The cuBLAS and cuSolver handles must have their streams set to the user's
!  CUDA stream first -- failing to do so gives CUEST_STATUS_EXCEPTION.
!
!  Structure follows the C sample call for call:
!    stream -> cuBLAS -> cuSolver -> set streams -> parameters -> configure
!           -> cuestCreate -> cuestDestroy -> destroy the user's resources
!
!  Difference from the C sample: it exits without printing anything. This port
!  reports whether cuBLAS and cuSolver really carry the user's stream, and that
!  the cuEST handle came back live.
!
!  cuBLAS and cuSolver have no generated Fortran bindings in this tree, so the
!  five entry points used here are declared locally. The CUDA runtime calls all
!  come from the generated `cuda_runtime` module.
!
!  Usage:  ./user_owned_resources
! ============================================================================
program user_owned_resources
    use, intrinsic :: iso_c_binding
    use, intrinsic :: iso_fortran_env, only: error_unit
    use cuest
    use cuda_runtime, only: cudaStreamCreate, cudaStreamDestroy, cudaSuccess
    use cuest_sample_utils, only: cuest_check, scalar_report
    implicit none

    ! cublas_v2.h maps cublasCreate/Destroy/SetStream/GetStream onto the _v2
    ! symbols; cuSolverDn exports its names directly. Both status enums use 0
    ! for success.
    integer(c_int), parameter :: CUBLAS_STATUS_SUCCESS = 0
    integer(c_int), parameter :: CUSOLVER_STATUS_SUCCESS = 0

    interface
        integer(c_int) function cublasCreate(handle) bind(C, name="cublasCreate_v2")
            import :: c_int, c_ptr
            type(c_ptr), intent(out) :: handle
        end function cublasCreate

        integer(c_int) function cublasDestroy(handle) bind(C, name="cublasDestroy_v2")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
        end function cublasDestroy

        integer(c_int) function cublasSetStream(handle, streamId) &
                bind(C, name="cublasSetStream_v2")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
            type(c_ptr), value :: streamId
        end function cublasSetStream

        integer(c_int) function cublasGetStream(handle, streamId) &
                bind(C, name="cublasGetStream_v2")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
            type(c_ptr), intent(out) :: streamId
        end function cublasGetStream

        integer(c_int) function cusolverDnCreate(handle) bind(C, name="cusolverDnCreate")
            import :: c_int, c_ptr
            type(c_ptr), intent(out) :: handle
        end function cusolverDnCreate

        integer(c_int) function cusolverDnDestroy(handle) bind(C, name="cusolverDnDestroy")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
        end function cusolverDnDestroy

        integer(c_int) function cusolverDnSetStream(handle, streamId) &
                bind(C, name="cusolverDnSetStream")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
            type(c_ptr), value :: streamId
        end function cusolverDnSetStream

        integer(c_int) function cusolverDnGetStream(handle, streamId) &
                bind(C, name="cusolverDnGetStream")
            import :: c_int, c_ptr
            type(c_ptr), value :: handle
            type(c_ptr), intent(out) :: streamId
        end function cusolverDnGetStream
    end interface

    type(c_ptr), target :: stream_handle   = c_null_ptr
    type(c_ptr), target :: cublas_handle   = c_null_ptr
    type(c_ptr), target :: cusolver_handle = c_null_ptr

    !> The cuEST handle and the parameters for its creation.
    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: handle_parameters = c_null_ptr

    type(c_ptr)    :: queried_stream = c_null_ptr
    real(c_double) :: cublas_ok, cusolver_ok, handle_ok
    integer(c_int) :: ist

    ! ---- 1. the CUDA stream ------------------------------------------------
    if (cudaStreamCreate(stream_handle) /= cudaSuccess) then
        write(error_unit,'(A)') "Failed to create CUDA stream."
        error stop 1
    end if

    ! ---- 2. the cuBLAS handle ----------------------------------------------
    if (cublasCreate(cublas_handle) /= CUBLAS_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to create cuBLAS handle."
        error stop 1
    end if

    ! ---- 3. the cuSolver handle --------------------------------------------
    if (cusolverDnCreate(cusolver_handle) /= CUSOLVER_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to create cuSolverDn handle."
        error stop 1
    end if

    ! ---- 4. both must run on the user's stream -----------------------------
    if (cublasSetStream(cublas_handle, stream_handle) /= CUBLAS_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to set cuBLAS stream."
        error stop 1
    end if
    if (cusolverDnSetStream(cusolver_handle, stream_handle) /= CUSOLVER_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to set cuSolverDn stream."
        error stop 1
    end if

    ! ---- 5. handle parameters carrying the user's resources ----------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersCreate(handle)")

    call cuest_check(cuestParametersConfigure(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_CUDASTREAM, &
                     c_loc(stream_handle), c_sizeof(stream_handle)), &
                     "ParametersConfigure(CUDASTREAM)")
    call cuest_check(cuestParametersConfigure(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_CUBLAS, &
                     c_loc(cublas_handle), c_sizeof(cublas_handle)), &
                     "ParametersConfigure(CUBLAS)")
    call cuest_check(cuestParametersConfigure(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters, CUEST_HANDLE_PARAMETERS_CUSOLVER, &
                     c_loc(cusolver_handle), c_sizeof(cusolver_handle)), &
                     "ParametersConfigure(CUSOLVER)")

    ! ---- 6. create the cuEST handle ----------------------------------------
    call cuest_check(cuestCreate(handle_parameters, handle), "cuestCreate")

    ! Destroying the parameters frees only the parameter object, not the
    ! stream, cuBLAS and cuSolver handles.
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, &
                     handle_parameters), "ParametersDestroy(handle)")

    ! This is where the cuEST handle would normally be used; other GPU work
    ! should use the same stream, cuBLAS and cuSolver handles.

    ! ---- 7. report ---------------------------------------------------------
    ! The user's resources must still be attached to the user's stream.
    if (cublasGetStream(cublas_handle, queried_stream) /= CUBLAS_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to query cuBLAS stream."
        error stop 1
    end if
    cublas_ok = 0.0d0
    if (c_associated(queried_stream, stream_handle)) cublas_ok = 1.0d0

    if (cusolverDnGetStream(cusolver_handle, queried_stream) /= CUSOLVER_STATUS_SUCCESS) then
        write(error_unit,'(A)') "Failed to query cuSolverDn stream."
        error stop 1
    end if
    cusolver_ok = 0.0d0
    if (c_associated(queried_stream, stream_handle)) cusolver_ok = 1.0d0

    handle_ok = 0.0d0
    if (c_associated(handle)) handle_ok = 1.0d0

    call scalar_report("cuBLAS stream is the user stream", cublas_ok)
    call scalar_report("cuSolver stream is the user stream", cusolver_ok)
    call scalar_report("cuEST handles created", handle_ok)

    ! ---- 8. teardown -------------------------------------------------------
    ! Destroying the cuEST handle does not destroy the user's resources.
    call cuest_check(cuestDestroy(handle), "cuestDestroy")

    ist = cusolverDnDestroy(cusolver_handle)
    if (ist /= CUSOLVER_STATUS_SUCCESS) &
        write(error_unit,'(A)') "warning: cusolverDnDestroy failed"
    ist = cublasDestroy(cublas_handle)
    if (ist /= CUBLAS_STATUS_SUCCESS) &
        write(error_unit,'(A)') "warning: cublasDestroy failed"
    ist = cudaStreamDestroy(stream_handle)
    if (ist /= cudaSuccess) &
        write(error_unit,'(A)') "warning: cudaStreamDestroy failed"

end program user_owned_resources
