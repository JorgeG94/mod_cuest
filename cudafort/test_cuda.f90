! ============================================================================
!  test_cuda.f90 -- exercises the generated CUDA bindings end to end.
!
!  Deliberately uses no cuEST, so it runs on ANY CUDA GPU including Volta.
!
!  Build & run:   make test && ./test_cuda
! ============================================================================
program test_cuda
    use, intrinsic :: iso_c_binding
    use cuda_runtime
    use cuda_helpers
    implicit none

    integer :: failures = 0

    write(*,'(A)') "=========================================================="
    write(*,'(A)') " cudafort self-test"
    write(*,'(A)') "=========================================================="

    call t_version()
    call t_devices()
    call t_malloc_memcpy()
    call t_streams()
    call t_events()
    call t_async()
    call t_pinned()
    call t_error_decoding()
    call t_device_prop_layout()

    write(*,'(A)') "----------------------------------------------------------"
    if (failures == 0) then
        write(*,'(A)') "ALL TESTS PASSED"
    else
        write(*,'(A,I0,A)') "FAILURES: ", failures, " test(s) failed"
        error stop 1
    end if

contains

    subroutine ok(cond, what)
        logical,      intent(in) :: cond
        character(*), intent(in) :: what
        if (cond) then
            write(*,'(A,A)') "  [ ok ] ", what
        else
            write(*,'(A,A)') "  [FAIL] ", what
            failures = failures + 1
        end if
    end subroutine ok

    ! -- driver / runtime version ------------------------------------------
    subroutine t_version()
        integer(c_int) :: ist, rt = 0, drv = 0
        write(*,'(A)') "-- version"
        ist = cudaRuntimeGetVersion(rt)
        call ok(ist == cudaSuccess .and. rt > 0, "cudaRuntimeGetVersion")
        ist = cudaDriverGetVersion(drv)
        call ok(ist == cudaSuccess .and. drv > 0, "cudaDriverGetVersion")
        write(*,'(A,I0,A,I0)') "         runtime=", rt, "  driver=", drv
    end subroutine t_version

    ! -- device enumeration and properties ---------------------------------
    subroutine t_devices()
        integer(c_int) :: ist, ndev = 0
        write(*,'(A)') "-- devices"
        ist = cudaGetDeviceCount(ndev)
        call ok(ist == cudaSuccess .and. ndev > 0, "cudaGetDeviceCount > 0")
        if (ndev > 0) call cuda_report_devices()
    end subroutine t_devices

    ! -- the core allocate / copy / verify round trip ----------------------
    subroutine t_malloc_memcpy()
        integer, parameter :: n = 1024
        real(c_double), allocatable, target :: h(:), back(:)
        type(c_ptr)    :: d = c_null_ptr
        integer(c_int) :: ist
        integer :: i
        write(*,'(A)') "-- malloc / memcpy round trip"
        allocate(h(n), back(n))
        do i = 1, n
            h(i) = real(i, c_double) * 0.5d0
        end do
        back = -1.0d0

        ist = cudaMalloc(d, int(n, c_size_t) * 8_c_size_t)
        call ok(ist == cudaSuccess .and. c_associated(d), "cudaMalloc")
        ist = cuda_memcpy_to_device(d, h)
        call ok(ist == cudaSuccess, "cudaMemcpy host->device")
        ist = cuda_memcpy_to_host(back, d)
        call ok(ist == cudaSuccess, "cudaMemcpy device->host")
        call ok(all(abs(back - h) < 1.0d-15), "round-tripped data matches")

        ist = cudaMemset(d, 0, int(n, c_size_t) * 8_c_size_t)
        call ok(ist == cudaSuccess, "cudaMemset")
        ist = cuda_memcpy_to_host(back, d)
        call ok(all(back == 0.0d0), "cudaMemset zeroed the buffer")

        ist = cuda_free(d)
        call ok(ist == cudaSuccess, "cudaFree")
        deallocate(h, back)
    end subroutine t_malloc_memcpy

    ! -- streams ------------------------------------------------------------
    subroutine t_streams()
        type(c_ptr)    :: s1 = c_null_ptr, s2 = c_null_ptr
        integer(c_int) :: ist, prio_lo = 0, prio_hi = 0
        write(*,'(A)') "-- streams"
        ist = cudaStreamCreate(s1)
        call ok(ist == cudaSuccess .and. c_associated(s1), "cudaStreamCreate")
        ist = cudaStreamCreateWithFlags(s2, cudaStreamNonBlocking)
        call ok(ist == cudaSuccess, "cudaStreamCreateWithFlags(NonBlocking)")
        ist = cudaDeviceGetStreamPriorityRange(prio_lo, prio_hi)
        call ok(ist == cudaSuccess, "cudaDeviceGetStreamPriorityRange")
        ist = cudaStreamSynchronize(s1)
        call ok(ist == cudaSuccess, "cudaStreamSynchronize")
        ist = cudaStreamDestroy(s1)
        call ok(ist == cudaSuccess, "cudaStreamDestroy")
        ist = cudaStreamDestroy(s2)
        call ok(ist == cudaSuccess, "cudaStreamDestroy (2)")
    end subroutine t_streams

    ! -- events and timing --------------------------------------------------
    subroutine t_events()
        type(c_ptr)    :: e1 = c_null_ptr, e2 = c_null_ptr, d = c_null_ptr
        integer(c_int) :: ist
        real(c_float)  :: ms = -1.0
        write(*,'(A)') "-- events"
        ist = cudaEventCreate(e1)
        call ok(ist == cudaSuccess, "cudaEventCreate")
        ist = cudaEventCreateWithFlags(e2, cudaEventDefault)
        call ok(ist == cudaSuccess, "cudaEventCreateWithFlags")

        ist = cudaMalloc(d, 8_c_size_t * 1024_c_size_t * 1024_c_size_t)
        call cuda_check(ist, "cudaMalloc for timing")
        ist = cudaEventRecord(e1, c_null_ptr)
        ist = cudaMemset(d, 1, 8_c_size_t * 1024_c_size_t * 1024_c_size_t)
        ist = cudaEventRecord(e2, c_null_ptr)
        ist = cudaEventSynchronize(e2)
        call ok(ist == cudaSuccess, "cudaEventSynchronize")
        ist = cudaEventElapsedTime(ms, e1, e2)
        call ok(ist == cudaSuccess .and. ms >= 0.0, &
                "cudaEventElapsedTime returns a sane duration")
        write(*,'(A,F8.4,A)') "         8 MiB memset took ", ms, " ms"

        ist = cuda_free(d)
        ist = cudaEventDestroy(e1)
        call ok(ist == cudaSuccess, "cudaEventDestroy")
        ist = cudaEventDestroy(e2)
    end subroutine t_events

    ! -- asynchronous copies on a stream ------------------------------------
    subroutine t_async()
        integer, parameter :: n = 4096
        real(c_double), allocatable, target :: h(:), back(:)
        type(c_ptr)    :: d = c_null_ptr, s = c_null_ptr
        integer(c_int) :: ist
        write(*,'(A)') "-- async copies"
        allocate(h(n), back(n))
        h = 3.25d0
        back = 0.0d0
        ist = cudaStreamCreate(s)
        call cuda_check(ist, "cudaStreamCreate")
        ist = cudaMalloc(d, int(n, c_size_t) * 8_c_size_t)
        call cuda_check(ist, "cudaMalloc")

        ist = cudaMemcpyAsync(d, c_loc(h), int(n, c_size_t) * 8_c_size_t, &
                              cudaMemcpyHostToDevice, s)
        call ok(ist == cudaSuccess, "cudaMemcpyAsync H2D")
        ist = cudaMemcpyAsync(c_loc(back), d, int(n, c_size_t) * 8_c_size_t, &
                              cudaMemcpyDeviceToHost, s)
        call ok(ist == cudaSuccess, "cudaMemcpyAsync D2H")
        ist = cudaStreamSynchronize(s)
        call ok(ist == cudaSuccess, "cudaStreamSynchronize")
        call ok(all(back == 3.25d0), "async round trip preserved data")

        ist = cuda_free(d)
        ist = cudaStreamDestroy(s)
        deallocate(h, back)
    end subroutine t_async

    ! -- pinned host memory -------------------------------------------------
    subroutine t_pinned()
        type(c_ptr)    :: hp = c_null_ptr
        integer(c_int) :: ist
        real(c_double), pointer :: fp(:)
        write(*,'(A)') "-- pinned host memory"
        ist = cudaHostAlloc(hp, 1024_c_size_t * 8_c_size_t, cudaHostAllocDefault)
        call ok(ist == cudaSuccess .and. c_associated(hp), "cudaHostAlloc")
        if (c_associated(hp)) then
            call c_f_pointer(hp, fp, [1024])
            fp(1) = 42.0d0
            fp(1024) = 7.0d0
            call ok(fp(1) == 42.0d0 .and. fp(1024) == 7.0d0, &
                    "pinned buffer is writable through a Fortran pointer")
            ist = cudaFreeHost(hp)
            call ok(ist == cudaSuccess, "cudaFreeHost")
        end if
    end subroutine t_pinned

    ! -- error decoding -----------------------------------------------------
    subroutine t_error_decoding()
        integer(c_int) :: ist
        type(c_ptr)    :: d = c_null_ptr
        write(*,'(A)') "-- error decoding"
        call ok(trim(cuda_error_name(cudaSuccess)) == "cudaSuccess", &
                "cudaGetErrorName(cudaSuccess) decodes")
        call ok(len(cuda_error_string(cudaErrorInvalidValue)) > 0, &
                "cudaGetErrorString returns a message")
        ! Ask for an absurd allocation: must fail cleanly, not crash.
        ist = cudaMalloc(d, huge(0_c_size_t))
        call ok(ist /= cudaSuccess, "oversized cudaMalloc fails gracefully")
        write(*,'(A,A)') "         reported: ", cuda_error_name(ist)
        ist = cudaGetLastError()          ! clear the sticky error
    end subroutine t_error_decoding

    ! -- struct layout sanity ----------------------------------------------
    !  The generator verified sizeof/offsetof at build time; this confirms the
    !  values actually survive the call at run time.
    subroutine t_device_prop_layout()
        type(cudaDeviceProp) :: prop
        integer(c_int)       :: ist
        write(*,'(A)') "-- cudaDeviceProp layout"
        ist = cudaGetDeviceProperties(prop, 0)
        call ok(ist == cudaSuccess, "cudaGetDeviceProperties (bound to _v2)")
        call ok(len(cuda_device_name(prop)) > 0, "device name is non-empty")
        call ok(prop%major > 0, "major compute capability is plausible")
        call ok(prop%totalGlobalMem > 0, "totalGlobalMem is plausible")
        call ok(prop%warpSize == 32, "warpSize == 32")
        call ok(prop%maxThreadsPerBlock >= 512, &
                "maxThreadsPerBlock is plausible")
        call ok(prop%multiProcessorCount > 0, "multiProcessorCount > 0")
        call ok(prop%maxThreadsDim(1) > 0 .and. prop%maxGridSize(1) > 0, &
                "array members readable (maxThreadsDim / maxGridSize)")
    end subroutine t_device_prop_layout

end program test_cuda
