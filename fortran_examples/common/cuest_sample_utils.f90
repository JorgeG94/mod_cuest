! ============================================================================
!  cuest_sample_utils.f90 -- shared scaffolding for the Fortran sample ports.
!
!  Fortran counterpart of the C samples' common/helper_status.h and
!  common/helper_workspaces.h, plus the device-memory and reporting bits each
!  sample would otherwise re-implement.
!
!  Provides:
!    cuest_check / cuda_ck   -- abort with a decoded status
!    ws_alloc / ws_free      -- cuestWorkspace_t from a descriptor
!    dev_alloc / dev_free    -- device buffers counted in doubles
!    dev_to_host             -- pull a device matrix back
!    matrix_report           -- numeric fingerprint of a matrix, for diffing
!    arg / require_args      -- command-line handling
! ============================================================================
module cuest_sample_utils
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_status_name
    use cuda_runtime
    use cuda_helpers, only: cuda_check
    implicit none
    private

    public :: cuest_check, cuda_ck
    public :: ws_alloc, ws_free
    public :: dev_alloc, dev_free, dev_to_host
    public :: matrix_report, array_report, scalar_report
    public :: arg, require_args

    !> Plain C malloc/free for the host half of a cuEST workspace. The C helper
    !  uses malloc, and the buffer must outlive any Fortran scoping unit, so a
    !  Fortran allocatable is not a substitute.
    interface
        type(c_ptr) function c_malloc(sz) bind(C, name="malloc")
            import :: c_ptr, c_size_t
            integer(c_size_t), value :: sz
        end function c_malloc
        subroutine c_free(p) bind(C, name="free")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine c_free
    end interface

contains

    !> Abort with a named status if a cuEST call did not succeed.
    subroutine cuest_check(status, what)
        integer(c_int), intent(in) :: status
        character(*),   intent(in) :: what
        if (status /= CUEST_STATUS_SUCCESS) then
            write(*,'(A,A,A,I0,A,A,A)') "cuEST FAILED: ", what, " status=", &
                status, " (", cuest_status_name(status), ")"
            error stop 1
        end if
    end subroutine cuest_check

    !> Same for a CUDA runtime call (thin alias, so samples need one idiom).
    subroutine cuda_ck(code, what)
        integer(c_int), intent(in) :: code
        character(*),   intent(in) :: what
        call cuda_check(code, what)
    end subroutine cuda_ck

    ! ---- workspaces -------------------------------------------------------

    !> Allocate host and device scratch sized by a descriptor and record the
    !  raw addresses in a cuestWorkspace_t.
    !
    !  The buffer fields are uintptr_t in C, not pointers, so a TRANSFER is the
    !  correct way to store an address in them.
    subroutine ws_alloc(ws, desc)
        type(cuestWorkspace_t),           intent(out) :: ws
        type(cuestWorkspaceDescriptor_t), intent(in)  :: desc
        type(c_ptr) :: dptr, hptr
        ws%hostBufferSizeInBytes   = desc%hostBufferSizeInBytes
        ws%deviceBufferSizeInBytes = desc%deviceBufferSizeInBytes
        ws%hostBuffer   = 0_c_intptr_t
        ws%deviceBuffer = 0_c_intptr_t
        if (desc%hostBufferSizeInBytes > 0) then
            hptr = c_malloc(desc%hostBufferSizeInBytes)
            if (.not. c_associated(hptr)) then
                write(*,'(A)') "failed to allocate workspace host buffer"
                error stop 2
            end if
            ws%hostBuffer = transfer(hptr, ws%hostBuffer)
        end if
        if (desc%deviceBufferSizeInBytes > 0) then
            call cuda_check(cudaMalloc(dptr, desc%deviceBufferSizeInBytes), &
                            "cudaMalloc(workspace)")
            ws%deviceBuffer = transfer(dptr, ws%deviceBuffer)
        end if
    end subroutine ws_alloc

    subroutine ws_free(ws)
        type(cuestWorkspace_t), intent(inout) :: ws
        integer(c_int) :: ist
        if (ws%hostBuffer /= 0_c_intptr_t) &
            call c_free(transfer(ws%hostBuffer, c_null_ptr))
        if (ws%deviceBuffer /= 0_c_intptr_t) then
            ist = cudaFree(transfer(ws%deviceBuffer, c_null_ptr))
            call cuda_check(ist, "cudaFree(workspace)")
        end if
        ws%hostBuffer   = 0_c_intptr_t
        ws%deviceBuffer = 0_c_intptr_t
        ws%hostBufferSizeInBytes   = 0_c_size_t
        ws%deviceBufferSizeInBytes = 0_c_size_t
    end subroutine ws_free

    ! ---- device memory ----------------------------------------------------

    !> Allocate `n` doubles on the device.
    type(c_ptr) function dev_alloc(n) result(p)
        integer(c_int64_t), intent(in) :: n
        p = c_null_ptr
        call cuda_check(cudaMalloc(p, int(n, c_size_t) * 8_c_size_t), &
                        "cudaMalloc(device array)")
    end function dev_alloc

    subroutine dev_free(p)
        type(c_ptr), intent(inout) :: p
        if (c_associated(p)) call cuda_check(cudaFree(p), "cudaFree")
        p = c_null_ptr
    end subroutine dev_free

    !> Copy `n` doubles from the device into a host array.
    subroutine dev_to_host(host, dev, n)
        real(c_double), intent(out), target :: host(:)
        type(c_ptr),        intent(in) :: dev
        integer(c_int64_t), intent(in) :: n
        call cuda_check(cudaMemcpy(c_loc(host), dev, &
                        int(n, c_size_t) * 8_c_size_t, &
                        cudaMemcpyDeviceToHost), "cudaMemcpy(D2H)")
    end subroutine dev_to_host

    ! ---- reporting --------------------------------------------------------

    !> Print a numeric fingerprint of an n x n matrix held as a flat array.
    !
    !  The C samples compute these integrals but never print them, so there is
    !  no reference output to diff against directly. Trace, Frobenius norm and
    !  a corner block are stable, basis-ordering-sensitive quantities that make
    !  a useful comparison once the C side is instrumented to match.
    subroutine matrix_report(label, a, n)
        character(*),       intent(in) :: label
        real(c_double),     intent(in) :: a(:)
        integer(c_int64_t), intent(in) :: n
        real(c_double) :: tr, fro, asym, d
        integer :: i, j, m
        tr = 0.0d0
        fro = 0.0d0
        asym = 0.0d0
        do i = 1, int(n)
            tr = tr + a((i-1)*n + i)
            do j = 1, int(n)
                fro = fro + a((i-1)*n + j)**2
                d = abs(a((i-1)*n + j) - a((j-1)*n + i))
                if (d > asym) asym = d
            end do
        end do
        fro = sqrt(fro)
        write(*,'(A)')      "  " // repeat("-", 60)
        write(*,'(A,A)')    "  matrix ", label
        write(*,'(A,I0,A,I0)') "    dimension      : ", n, " x ", n
        write(*,'(A,ES22.14)') "    trace          : ", tr
        write(*,'(A,ES22.14)') "    Frobenius norm : ", fro
        write(*,'(A,ES10.2)')  "    max |A-A^T|    : ", asym
        m = min(5, int(n))
        write(*,'(A,I0,A,I0,A)') "    leading ", m, " x ", m, " block:"
        do i = 1, m
            ! Scientific, not F editing: F overflows to asterisks for values
            ! that do not fit the field, and C's %f silently widens instead --
            ! so a large matrix element would print as **** on one side only.
            write(*,'(6X,*(1X,ES21.14E2))') (a((i-1)*n + j), j = 1, m)
        end do
    end subroutine matrix_report

    !> Print a fingerprint of a flat array -- gradients, dipoles, charges.
    !
    !  Format is matched exactly by oracle/oracle_report.h :: oracle_report_array
    !  and parsed by compare.py. Change one, change all three.
    subroutine array_report(label, a, n)
        character(*),       intent(in) :: label
        real(c_double),     intent(in) :: a(:)
        integer(c_int64_t), intent(in) :: n
        real(c_double) :: s, nrm, amax, l1
        integer :: i, m
        s = 0.0d0
        nrm = 0.0d0
        amax = 0.0d0
        l1 = 0.0d0
        do i = 1, int(n)
            s = s + a(i)
            l1 = l1 + abs(a(i))
            nrm = nrm + a(i)**2
            if (abs(a(i)) > amax) amax = abs(a(i))
        end do
        nrm = sqrt(nrm)
        m = min(12, int(n))
        write(*,'(A)')      "  " // repeat("-", 60)
        write(*,'(A,A)')    "  array ", label
        write(*,'(A,I0)')      "    length         : ", n
        write(*,'(A,ES22.14)') "    sum            : ", s
        ! L1 is invariant under sign flips while `sum` is not -- see the note in
        ! oracle/oracle_report.h. Agreeing in norm and L1 but not in sum means
        ! the same values with some signs differing.
        write(*,'(A,ES22.14)') "    sum |a_i|      : ", l1
        write(*,'(A,ES22.14)') "    norm           : ", nrm
        write(*,'(A,ES22.14)') "    max |a_i|      : ", amax
        write(*,'(A,I0,A)')    "    first ", m, " values:"
        do i = 1, m
            ! See matrix_report: F editing cannot widen, C's %f can.
            write(*,'(1X,ES21.14E2)', advance="no") a(i)
            if (mod(i, 6) == 0 .or. i == m) write(*,'(A)') ""
        end do
    end subroutine array_report

    !> Print a single number -- an energy, a trace, a count.
    subroutine scalar_report(label, v)
        character(*),   intent(in) :: label
        real(c_double), intent(in) :: v
        write(*,'(A)')      "  " // repeat("-", 60)
        write(*,'(A,A)')    "  scalar ", label
        write(*,'(A,ES22.14)') "    value          : ", v
    end subroutine scalar_report

    ! ---- command line -----------------------------------------------------

    !> The i-th command-line argument as a trimmed string.
    function arg(i) result(s)
        integer, intent(in) :: i
        character(len=:), allocatable :: s
        integer :: n
        call get_command_argument(i, length=n)
        allocate(character(len=n) :: s)
        call get_command_argument(i, value=s)
    end function arg

    !> Abort with a usage message unless exactly `n` arguments were supplied.
    subroutine require_args(n, usage)
        integer,      intent(in) :: n
        character(*), intent(in) :: usage
        character(len=:), allocatable :: exe
        integer :: l
        if (command_argument_count() /= n) then
            call get_command_argument(0, length=l)
            allocate(character(len=l) :: exe)
            call get_command_argument(0, value=exe)
            write(*,'(A,A,A,A)') "Usage: ", exe, " ", usage
            error stop 1
        end if
    end subroutine require_args

end module cuest_sample_utils
