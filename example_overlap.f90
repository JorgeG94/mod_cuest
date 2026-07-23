! ============================================================================
!  example_overlap.f90
!
!  Complete, runnable demonstration of driving NVIDIA cuEST from Fortran via the
!  `cuest` interface module (+ `cuest_helpers`).  It computes the AO overlap
!  matrix S for an H2 molecule with a minimal STO-3G basis and copies it back
!  to the host for printing.
!
!  It mirrors, call for call, the C sample
!    CUDALibrarySamples/cuEST/c_examples/examples/2_one_electron_integrals/
!  and shows the four idioms a Fortran caller needs:
!    1. status checking             -- every call returns cuestStatus_t
!    2. one parameters object per step -- created, never NULL, then destroyed
!    3. the generic query API        -- via the typed cuest_helpers wrappers
!    4. workspace + device memory    -- query -> allocate -> create/compute
!
!  cuEST integral buffers are GPU DEVICE pointers, so the output S lives on the
!  device and is wired with a minimal CUDA runtime interface (module cuda_rt).
!  Shell exponents/coefficients and pair-list coordinates are HOST arrays.
!
!  Build (Linux/x86_64 box with the cuEST package + CUDA):
!    make example CUDA_LIBDIR=<your cuda lib64>
!  or by hand:
!    gfortran -c cuest.f90 cuest_helpers.f90
!    gfortran example_overlap.f90 cuest.o cuest_helpers.o -o overlap_demo \
!       -L../lib -lcuest -L<cuda>/lib64 -lcudart -lcublas -lcusolver -lpthread -lm \
!       -Wl,-rpath,../lib
! ============================================================================

module cuda_rt
    !! Minimal bindings to the CUDA runtime + C malloc/free the example needs.
    use, intrinsic :: iso_c_binding
    implicit none
    integer(c_int), parameter :: cudaMemcpyHostToDevice = 1
    integer(c_int), parameter :: cudaMemcpyDeviceToHost = 2
    interface
        integer(c_int) function cudaMalloc(devPtr, sz) bind(C, name="cudaMalloc")
            import :: c_int, c_ptr, c_size_t
            type(c_ptr),       intent(out) :: devPtr
            integer(c_size_t), value       :: sz
        end function cudaMalloc
        integer(c_int) function cudaFree(devPtr) bind(C, name="cudaFree")
            import :: c_int, c_ptr
            type(c_ptr), value :: devPtr
        end function cudaFree
        integer(c_int) function cudaMemcpy(dst, src, sz, kind) bind(C, name="cudaMemcpy")
            import :: c_int, c_ptr, c_size_t
            type(c_ptr),       value :: dst, src
            integer(c_size_t), value :: sz
            integer(c_int),    value :: kind
        end function cudaMemcpy
        integer(c_int) function cudaDeviceSynchronize() bind(C, name="cudaDeviceSynchronize")
            import :: c_int
        end function cudaDeviceSynchronize
        ! plain host memory for cuEST host workspace buffers (matches the C helper)
        type(c_ptr) function c_malloc(sz) bind(C, name="malloc")
            import :: c_ptr, c_size_t
            integer(c_size_t), value :: sz
        end function c_malloc
        subroutine c_free(p) bind(C, name="free")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine c_free
    end interface
end module cuda_rt


program overlap_demo
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers
    use cuda_rt
    implicit none

    integer(c_int) :: ist
    type(c_ptr)    :: handle = c_null_ptr, hpar = c_null_ptr
    type(c_ptr)    :: sh_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr)    :: pl_par = c_null_ptr, plan_par = c_null_ptr, ov_par = c_null_ptr
    type(c_ptr)    :: basis = c_null_ptr, pairList = c_null_ptr, plan = c_null_ptr
    type(c_ptr)    :: dS = c_null_ptr
    integer        :: i

    ! ---- an H2 molecule, minimal STO-3G basis (one s-shell per H atom) ----
    integer(c_int64_t), parameter :: numAtoms = 2
    integer(c_int32_t) :: isPure = 1
    integer(c_int64_t) :: L = 0, nprim = 3
    real(c_double), target :: expo(3) = [ 3.42525091d0, 0.62391373d0, 0.16885540d0 ]
    real(c_double), target :: coef(3) = [ 0.15432897d0, 0.53532814d0, 0.44463454d0 ]
    integer(c_int64_t), target :: nShellsPerAtom(2) = [ 1_c_int64_t, 1_c_int64_t ]
    type(c_ptr) :: shells(2) = c_null_ptr
    ! atom coordinates in bohr, layout [x0,y0,z0, x1,y1,z1] (host)
    real(c_double), target :: xyz(6) = [ 0.d0, 0.d0, 0.d0,  0.d0, 0.d0, 1.4d0 ]

    integer(c_int64_t) :: nao = 0
    type(cuestWorkspaceDescriptor_t) :: dPersist, dTemp
    type(cuestWorkspace_t)           :: wPersistBasis, wPersistPL, wPersistPlan, wTmp
    real(c_double), allocatable, target :: Smat(:)

    write(*,'(A,I0,".",I0,".",I0)') "cuEST Fortran overlap demo -- headers v", &
         CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH

    ! ---- 1. context ------------------------------------------------------
    call chk(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, hpar), "ParametersCreate(handle)")
    call chk(cuestCreate(hpar, handle), "cuestCreate")
    call chk(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, hpar), "ParametersDestroy(handle)")

    ! ---- 2. AO shells (one identical H s-shell per atom) ------------------
    call chk(cuestParametersCreate(CUEST_AOSHELL_PARAMETERS, sh_par), "ParametersCreate(shell)")
    do i = 1, 2
        call chk(cuestAOShellCreate(handle, isPure, L, nprim, &
                 c_loc(expo), c_loc(coef), sh_par, shells(i)), "AOShellCreate")
    end do
    call chk(cuestParametersDestroy(CUEST_AOSHELL_PARAMETERS, sh_par), "ParametersDestroy(shell)")

    ! ---- 3. AO basis (query -> allocate -> create) -----------------------
    call chk(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, basis_par), "ParametersCreate(basis)")
    call chk(cuestAOBasisCreateWorkspaceQuery(handle, numAtoms, nShellsPerAtom, shells, &
             basis_par, dPersist, dTemp, basis), "AOBasisWSQuery")
    call make_ws(wPersistBasis, dPersist)
    call make_ws(wTmp, dTemp)
    call chk(cuestAOBasisCreate(handle, numAtoms, nShellsPerAtom, shells, basis_par, &
             wPersistBasis, wTmp, basis), "AOBasisCreate")
    call free_ws(wTmp)
    call chk(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, basis_par), "ParametersDestroy(basis)")

    call chk(cuest_query_i64(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_AO, nao), "query nao")
    write(*,'(A,I0)') "number of AOs (nao) = ", nao

    ! ---- 4. AO pair list (coordinates enter here; host xyz) --------------
    call chk(cuestParametersCreate(CUEST_AOPAIRLIST_PARAMETERS, pl_par), "ParametersCreate(pairlist)")
    call chk(cuestAOPairListCreateWorkspaceQuery(handle, basis, numAtoms, c_loc(xyz), &
             1.0d-14, pl_par, dPersist, dTemp, pairList), "PairListWSQuery")
    call make_ws(wPersistPL, dPersist)
    call make_ws(wTmp, dTemp)
    call chk(cuestAOPairListCreate(handle, basis, numAtoms, c_loc(xyz), 1.0d-14, pl_par, &
             wPersistPL, wTmp, pairList), "PairListCreate")
    call free_ws(wTmp)
    call chk(cuestParametersDestroy(CUEST_AOPAIRLIST_PARAMETERS, pl_par), "ParametersDestroy(pairlist)")

    ! ---- 5. one-electron integral plan -----------------------------------
    call chk(cuestParametersCreate(CUEST_OEINTPLAN_PARAMETERS, plan_par), "ParametersCreate(plan)")
    call chk(cuestOEIntPlanCreateWorkspaceQuery(handle, basis, pairList, plan_par, &
             dPersist, dTemp, plan), "PlanWSQuery")
    call make_ws(wPersistPlan, dPersist)
    call make_ws(wTmp, dTemp)
    call chk(cuestOEIntPlanCreate(handle, basis, pairList, plan_par, &
             wPersistPlan, wTmp, plan), "PlanCreate")
    call free_ws(wTmp)
    call chk(cuestParametersDestroy(CUEST_OEINTPLAN_PARAMETERS, plan_par), "ParametersDestroy(plan)")

    ! ---- 6. overlap: allocate S on device, query, compute ----------------
    call ccheck(cudaMalloc(dS, int(nao*nao, c_size_t) * 8_c_size_t), "cudaMalloc(S)")
    call chk(cuestParametersCreate(CUEST_OVERLAPCOMPUTE_PARAMETERS, ov_par), "ParametersCreate(overlap)")
    call chk(cuestOverlapComputeWorkspaceQuery(handle, plan, ov_par, dTemp, dS), "OverlapWSQuery")
    call make_ws(wTmp, dTemp)
    call chk(cuestOverlapCompute(handle, plan, ov_par, wTmp, dS), "OverlapCompute")
    call ccheck(cudaDeviceSynchronize(), "sync")
    call free_ws(wTmp)
    call chk(cuestParametersDestroy(CUEST_OVERLAPCOMPUTE_PARAMETERS, ov_par), "ParametersDestroy(overlap)")

    ! ---- 7. copy S back to the host and print ----------------------------
    allocate(Smat(nao*nao))
    call ccheck(cudaMemcpy(c_loc(Smat), dS, int(nao*nao,c_size_t)*8_c_size_t, &
                cudaMemcpyDeviceToHost), "cudaMemcpy(S->host)")
    write(*,'(A)') "overlap matrix S ="
    do i = 1, int(nao)
        write(*,'(*(1x,f12.8))') Smat((i-1)*nao + 1 : (i-1)*nao + nao)
    end do

    ! ---- 8. teardown -----------------------------------------------------
    ist = cudaFree(dS)
    call free_ws(wPersistPlan); call free_ws(wPersistPL); call free_ws(wPersistBasis)
    ist = cuestOEIntPlanDestroy(plan)
    ist = cuestAOPairListDestroy(pairList)
    ist = cuestAOBasisDestroy(basis)
    do i = 1, 2
        ist = cuestAOShellDestroy(shells(i))
    end do
    ist = cuestDestroy(handle)
    write(*,'(A)') "done."

contains

    !> Abort with a named status if a cuEST call did not succeed.
    subroutine chk(status, what)
        integer(c_int), intent(in) :: status
        character(*),   intent(in) :: what
        if (status /= CUEST_STATUS_SUCCESS) then
            write(*,'(A,A,A,I0,A,A,A)') "FAILED: ", what, " status=", status, &
                 " (", cuest_status_name(status), ")"
            error stop 1
        end if
    end subroutine chk

    !> Abort if a CUDA runtime call returned nonzero.
    subroutine ccheck(code, what)
        integer(c_int), intent(in) :: code
        character(*),   intent(in) :: what
        if (code /= 0) then
            write(*,'(A,A,A,I0)') "CUDA FAILED: ", what, " code=", code
            error stop 2
        end if
    end subroutine ccheck

    !> Allocate host (malloc) + device (cudaMalloc) scratch sized by a
    !  descriptor and record the raw addresses into a cuestWorkspace_t.
    subroutine make_ws(ws, desc)
        type(cuestWorkspace_t),           intent(out) :: ws
        type(cuestWorkspaceDescriptor_t), intent(in)  :: desc
        type(c_ptr) :: dptr
        ws%hostBufferSizeInBytes   = desc%hostBufferSizeInBytes
        ws%deviceBufferSizeInBytes = desc%deviceBufferSizeInBytes
        ws%hostBuffer   = 0_c_intptr_t
        ws%deviceBuffer = 0_c_intptr_t
        if (desc%hostBufferSizeInBytes > 0) &
            ws%hostBuffer = transfer(c_malloc(desc%hostBufferSizeInBytes), ws%hostBuffer)
        if (desc%deviceBufferSizeInBytes > 0) then
            call ccheck(cudaMalloc(dptr, desc%deviceBufferSizeInBytes), "cudaMalloc(workspace)")
            ws%deviceBuffer = transfer(dptr, ws%deviceBuffer)
        end if
    end subroutine make_ws

    subroutine free_ws(ws)
        type(cuestWorkspace_t), intent(inout) :: ws
        if (ws%hostBuffer   /= 0_c_intptr_t) call c_free(transfer(ws%hostBuffer, c_null_ptr))
        if (ws%deviceBuffer /= 0_c_intptr_t) ist = cudaFree(transfer(ws%deviceBuffer, c_null_ptr))
        ws%hostBuffer = 0_c_intptr_t
        ws%deviceBuffer = 0_c_intptr_t
    end subroutine free_ws

end program overlap_demo
