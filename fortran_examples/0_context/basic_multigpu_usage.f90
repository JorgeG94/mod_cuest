! ============================================================================
!  basic_multigpu_usage.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/0_context/
!    basic_multigpu_usage/main.c
!
!  Two cuEST handles on two GPUs, one per POSIX thread. A cuEST handle is only
!  valid on the device that was current when it was created, so both creation
!  and destruction happen on a thread that has called cudaSetDevice first.
!
!  Structure follows the C sample call for call: the same thread_args_t struct,
!  the same create/destroy worker functions, the same two pthread_create /
!  pthread_join rounds. The pthread entry points are module procedures because
!  Fortran forbids BIND(C) on an internal procedure, and C_FUNLOC needs one.
!
!  Difference from the C sample: it creates and destroys the handles and exits
!  without printing any result. This port additionally reports the number of
!  visible CUDA devices and the number of handles that came back live -- both
!  deterministic, unlike the interleaving of the per-thread messages.
!
!  Usage:  ./basic_multigpu_usage
! ============================================================================

!> The worker side: the argument struct and the two pthread entry points.
module basic_multigpu_usage_workers
    use, intrinsic :: iso_c_binding
    use, intrinsic :: iso_fortran_env, only: error_unit
    use cuest
    use cuda_runtime, only: cudaSetDevice, cudaSuccess
    use cuda_helpers, only: cuda_error_string
    use cuest_sample_utils, only: cuest_check
    implicit none
    private

    public :: thread_args_t, create_cuest_handle, destroy_cuest_handle

    !> Helper struct with the function arguments for pthread_create.
    type, bind(C) :: thread_args_t
        integer(c_int) :: thread_id
        type(c_ptr)    :: handle_ptr
    end type thread_args_t

contains

    !> Creates a cuEST handle on the GPU whose ID equals the thread ID. The
    !  handle is only valid on that GPU.
    !  RECURSIVE only so that gfortran is obliged to keep the locals on the
    !  stack: this runs on two threads at once and a SAVEd local would race.
    recursive function create_cuest_handle(arg) bind(C) result(res)
        type(c_ptr), value :: arg
        type(c_ptr) :: res

        type(thread_args_t), pointer :: args
        type(c_ptr),         pointer :: handle_out
        type(c_ptr) :: handle
        type(c_ptr) :: handle_parameters
        integer(c_int) :: err

        res = c_null_ptr
        handle = c_null_ptr
        handle_parameters = c_null_ptr
        call c_f_pointer(arg, args)
        call c_f_pointer(args%handle_ptr, handle_out)

        ! Switch to the GPU equal to thread_id.
        err = cudaSetDevice(args%thread_id)
        if (err /= cudaSuccess) then
            write(error_unit,'(A,I0,A,A)') "Thread ", args%thread_id, &
                ": cudaSetDevice failed: ", cuda_error_string(err)
            handle_out = c_null_ptr
            return
        end if

        write(*,'(A,I0,A,I0,A)') "Thread ", args%thread_id, &
            " creating cuEST handle on GPU ", args%thread_id, "."

        ! Create the cuEST handle.
        call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, &
                         handle_parameters), "ParametersCreate(handle)")
        call cuest_check(cuestCreate(handle_parameters, handle), "cuestCreate")
        call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, &
                         handle_parameters), "ParametersDestroy(handle)")
        handle_out = handle
    end function create_cuest_handle

    !> Destroys the handle with the matching GPU made current again.
    recursive function destroy_cuest_handle(arg) bind(C) result(res)
        type(c_ptr), value :: arg
        type(c_ptr) :: res

        type(thread_args_t), pointer :: args
        type(c_ptr),         pointer :: handle_out
        integer(c_int) :: err

        res = c_null_ptr
        call c_f_pointer(arg, args)
        call c_f_pointer(args%handle_ptr, handle_out)

        ! Switch to the GPU equal to thread_id.
        err = cudaSetDevice(args%thread_id)
        if (err /= cudaSuccess) then
            write(error_unit,'(A,I0,A,A)') "Thread ", args%thread_id, &
                ": cudaSetDevice failed: ", cuda_error_string(err)
            handle_out = c_null_ptr
            return
        end if

        write(*,'(A,I0,A,I0,A)') "Thread ", args%thread_id, &
            " destroying cuEST handle on GPU ", args%thread_id, "."

        ! Destroy the cuEST handle.
        call cuest_check(cuestDestroy(handle_out), "cuestDestroy")
    end function destroy_cuest_handle

end module basic_multigpu_usage_workers


program basic_multigpu_usage
    use, intrinsic :: iso_c_binding
    use, intrinsic :: iso_fortran_env, only: error_unit
    use cuda_runtime, only: cudaGetDeviceCount
    use cuest_sample_utils, only: cuda_ck, scalar_report
    use basic_multigpu_usage_workers
    implicit none

    !> pthread_t is an unsigned long on Linux, so an integer of pointer width
    !  holds it exactly. Only pthreads is declared here -- everything CUDA
    !  comes from the generated `cuda_runtime` bindings.
    interface
        integer(c_int) function pthread_create(thread, attr, start_routine, arg) &
                bind(C, name="pthread_create")
            import :: c_int, c_intptr_t, c_ptr, c_funptr
            integer(c_intptr_t), intent(out) :: thread
            type(c_ptr),    value :: attr
            type(c_funptr), value :: start_routine
            type(c_ptr),    value :: arg
        end function pthread_create

        integer(c_int) function pthread_join(thread, retval) &
                bind(C, name="pthread_join")
            import :: c_int, c_intptr_t, c_ptr
            integer(c_intptr_t), value :: thread
            type(c_ptr),         value :: retval
        end function pthread_join
    end interface

    !> Two threads and a cuEST handle for each.
    integer(c_intptr_t) :: thread1 = 0, thread2 = 0
    type(c_ptr),         target :: handles(2) = c_null_ptr
    type(thread_args_t), target :: args(2)

    integer(c_int) :: num_devices = 0
    real(c_double) :: num_created

    args(1)%thread_id  = 0_c_int
    args(1)%handle_ptr = c_loc(handles(1))

    args(2)%thread_id  = 1_c_int
    args(2)%handle_ptr = c_loc(handles(2))

    ! ---- 1. create the handles, one thread and one GPU each ----------------
    if (pthread_create(thread1, c_null_ptr, c_funloc(create_cuest_handle), &
                       c_loc(args(1))) /= 0) then
        write(error_unit,'(A)') "Failed to create thread 1"
        error stop 1
    end if
    if (pthread_create(thread2, c_null_ptr, c_funloc(create_cuest_handle), &
                       c_loc(args(2))) /= 0) then
        write(error_unit,'(A)') "Failed to create thread 2"
        error stop 1
    end if

    call join(thread1)
    call join(thread2)

    ! Two cuEST handles now exist, one on GPU 0 and one on GPU 1. Further cuEST
    ! calls would use the same threading model.

    ! Captured here, while the handles are still live.
    num_created = 0.0d0
    if (c_associated(handles(1))) num_created = num_created + 1.0d0
    if (c_associated(handles(2))) num_created = num_created + 1.0d0

    ! ---- 2. destroy them with the right device current ---------------------
    if (pthread_create(thread1, c_null_ptr, c_funloc(destroy_cuest_handle), &
                       c_loc(args(1))) /= 0) then
        write(error_unit,'(A)') "Failed to create thread 1"
        error stop 1
    end if
    if (pthread_create(thread2, c_null_ptr, c_funloc(destroy_cuest_handle), &
                       c_loc(args(2))) /= 0) then
        write(error_unit,'(A)') "Failed to create thread 2"
        error stop 1
    end if

    call join(thread1)
    call join(thread2)

    ! ---- 3. report ---------------------------------------------------------
    ! Reported after every join, so nothing here depends on how the threads
    ! were scheduled. The device count is queried rather than assumed because
    ! how far this sample gets depends on how many GPUs are visible.
    call cuda_ck(cudaGetDeviceCount(num_devices), "cudaGetDeviceCount")

    call scalar_report("visible CUDA devices", real(num_devices, c_double))
    call scalar_report("GPUs requested", 2.0d0)
    call scalar_report("cuEST handles created", num_created)

contains

    subroutine join(tid)
        integer(c_intptr_t), intent(in) :: tid
        if (pthread_join(tid, c_null_ptr) /= 0) then
            write(error_unit,'(A)') "pthread_join failed"
            error stop 1
        end if
    end subroutine join

end program basic_multigpu_usage
