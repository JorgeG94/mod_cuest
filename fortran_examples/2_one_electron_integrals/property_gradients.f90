! ============================================================================
!  property_gradients.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/2_one_electron_integrals/
!    property_gradients/main.c
!
!  Computes the nuclear derivatives of three property integral matrices,
!  contracted with a density matrix. As with every derivative routine in cuEST
!  the contraction is part of the call and the result is a numAtoms x 3 array.
!
!    dL/dR  angular momentum, Lz component, about the origin
!    dN/dR  nabla (momentum), x component
!    dM/dR  multipole of order (1,0,0) -- the x dipole -- about the origin
!
!  The property operators are contracted with a NON-symmetric pseudo-density
!  here (unlike one_electron_gradients, which uses a symmetric one) because
!  these operators are not symmetric. As in the C sample the matrix is
!  synthetic: a Box-Muller transform of consecutive rand() values after
!  srand(0). The port calls libc's srand()/rand() directly so the
!  pseudo-density is bit-identical to the C sample's.
!
!  Structure follows the C sample call for call:
!    handle -> AO shells -> AO basis -> AO pair list -> OE integral plan
!           -> synthetic density -> dL/dR, dN/dR, dM/dR into device buffers
!
!  Usage:  ./property_gradients <xyz_file> <gbs_file>
! ============================================================================
program property_gradients
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils
    use xyz_parser
    use gbs_parser
    use ao_shells
    implicit none

    !> glibc's rand()/srand(). Used verbatim so the synthetic density matches
    !  the C sample's element for element -- a Fortran RNG would not.
    interface
        subroutine c_srand(seed) bind(C, name="srand")
            import :: c_int
            integer(c_int), value :: seed
        end subroutine c_srand
        integer(c_int) function c_rand() bind(C, name="rand")
            import :: c_int
        end function c_rand
    end interface

    type(parsed_xyz_t),    target :: xyz
    type(ao_shell_data_t), target :: sd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr, basis_par = c_null_ptr
    type(c_ptr) :: pl_par = c_null_ptr, plan_par = c_null_ptr
    type(c_ptr) :: l_par = c_null_ptr, n_par = c_null_ptr, m_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr, pair_list = c_null_ptr, plan = c_null_ptr
    type(c_ptr) :: d_dldr = c_null_ptr, d_dndr = c_null_ptr
    type(c_ptr) :: d_dmdr = c_null_ptr, d_d = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_pl, ws_plan, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t
    real(c_double),     parameter :: PI = 3.14159265358979323846d0
    !> RAND_MAX on glibc; the C helper divides by RAND_MAX + 2.0.
    real(c_double),     parameter :: RAND_DIV = 2147483647.0d0 + 2.0d0

    ! Example operator settings -- identical to the C sample.
    integer(c_int),     parameter :: ANGULAR_COMPONENT = &
        CUEST_ANGULARMOMENTUMCOMPUTE_PARAMETERS_COMPONENT_LZ
    integer(c_int),     parameter :: NABLA_COMPONENT = &
        CUEST_NABLACOMPUTE_PARAMETERS_COMPONENT_X
    integer(c_int32_t) :: multipole_order(3) = [1_c_int32_t, 0_c_int32_t, 0_c_int32_t]
    real(c_double), target :: origin(3) = [0.0d0, 0.0d0, 0.0d0]

    integer(c_int64_t) :: nao = 0, num_atoms, ngrad
    real(c_double), allocatable :: h_grad(:), h_den(:)
    integer(c_int) :: ist

    call require_args(2, "<xyz_file> <gbs_file>")

    write(*,'(A,I0,".",I0,".",I0)') &
        "cuEST property gradients (Fortran port) -- headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH
    write(*,'(A,A)') "  geometry : ", arg(1)
    write(*,'(A,A)') "  basis    : ", arg(2)

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms
    ngrad = 3_c_int64_t * num_atoms
    write(*,'(A,I0)') "  atoms    : ", num_atoms

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. AO shells ------------------------------------------------------
    call form_ao_shells(handle, xyz, arg(2), IS_PURE, sd)
    write(*,'(A,I0)') "  shells   : ", sd%num_shells_total

    ! ---- 4. AO basis (query -> allocate -> create) -------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersCreate(basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     d_persist, d_temp, basis), "AOBasisCreateWorkspaceQuery")
    call ws_alloc(ws_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, num_atoms, &
                     sd%num_shells_per_atom, sd%shells, basis_par, &
                     ws_basis, ws_tmp, basis), "cuestAOBasisCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersDestroy(basis)")

    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    write(*,'(A,I0)') "  nao      : ", nao

    ! ---- 5. AO pair list (host coordinates enter here) ---------------------
    call cuest_check(cuestParametersCreate(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersCreate(pair list)")
    call make_pair_list()
    call cuest_check(cuestParametersDestroy(CUEST_AOPAIRLIST_PARAMETERS, pl_par), &
                     "ParametersDestroy(pair list)")

    ! ---- 6. one-electron integral plan -------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_OEINTPLAN_PARAMETERS, plan_par), &
                     "ParametersCreate(OE plan)")
    call cuest_check(cuestOEIntPlanCreateWorkspaceQuery(handle, basis, pair_list, &
                     plan_par, d_persist, d_temp, plan), "OEIntPlanWorkspaceQuery")
    call ws_alloc(ws_plan, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestOEIntPlanCreate(handle, basis, pair_list, plan_par, &
                     ws_plan, ws_tmp, plan), "cuestOEIntPlanCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_OEINTPLAN_PARAMETERS, plan_par), &
                     "ParametersDestroy(OE plan)")

    ! ---- 7. device buffers: three gradients plus the density ---------------
    d_dldr = dev_alloc(ngrad)
    d_dndr = dev_alloc(ngrad)
    d_dmdr = dev_alloc(ngrad)
    d_d    = dev_alloc(nao*nao)
    allocate(h_grad(ngrad))
    allocate(h_den(nao*nao))

    ! Fill the density with the same synthetic values the C sample uses.
    call fill_nonsymmetric_matrix(h_den, nao)
    call host_to_dev(d_d, h_den, nao*nao)

    ! ---- 8. angular momentum derivative (Lz about the origin) --------------
    call cuest_check(cuestParametersCreate( &
                     CUEST_ANGULARMOMENTUMDERIVATIVECOMPUTE_PARAMETERS, l_par), &
                     "ParametersCreate(angular momentum derivative)")
    call cuest_check(cuestAngularMomentumDerivativeComputeWorkspaceQuery(handle, &
                     plan, l_par, d_temp, ANGULAR_COMPONENT, c_loc(origin), &
                     d_d, d_dldr), &
                     "AngularMomentumDerivativeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAngularMomentumDerivativeCompute(handle, plan, l_par, &
                     ws_tmp, ANGULAR_COMPONENT, c_loc(origin), d_d, d_dldr), &
                     "cuestAngularMomentumDerivativeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_ANGULARMOMENTUMDERIVATIVECOMPUTE_PARAMETERS, l_par), &
                     "ParametersDestroy(angular momentum derivative)")

    ! ---- 9. nabla derivative (x component) ---------------------------------
    call cuest_check(cuestParametersCreate( &
                     CUEST_NABLADERIVATIVECOMPUTE_PARAMETERS, n_par), &
                     "ParametersCreate(nabla derivative)")
    call cuest_check(cuestNablaDerivativeComputeWorkspaceQuery(handle, plan, &
                     n_par, d_temp, NABLA_COMPONENT, d_d, d_dndr), &
                     "NablaDerivativeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestNablaDerivativeCompute(handle, plan, n_par, ws_tmp, &
                     NABLA_COMPONENT, d_d, d_dndr), &
                     "cuestNablaDerivativeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_NABLADERIVATIVECOMPUTE_PARAMETERS, n_par), &
                     "ParametersDestroy(nabla derivative)")

    ! ---- 10. multipole derivative (order 1,0,0 about the origin) -----------
    call cuest_check(cuestParametersCreate( &
                     CUEST_MULTIPOLEDERIVATIVECOMPUTE_PARAMETERS, m_par), &
                     "ParametersCreate(multipole derivative)")
    call cuest_check(cuestMultipoleDerivativeComputeWorkspaceQuery(handle, plan, &
                     m_par, d_temp, multipole_order, c_loc(origin), d_d, d_dmdr), &
                     "MultipoleDerivativeComputeWorkspaceQuery")
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestMultipoleDerivativeCompute(handle, plan, m_par, ws_tmp, &
                     multipole_order, c_loc(origin), d_d, d_dmdr), &
                     "cuestMultipoleDerivativeCompute")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy( &
                     CUEST_MULTIPOLEDERIVATIVECOMPUTE_PARAMETERS, m_par), &
                     "ParametersDestroy(multipole derivative)")

    call cuda_ck(cudaDeviceSynchronize(), "cudaDeviceSynchronize")

    ! ---- 11. report --------------------------------------------------------
    ! The density is reported too: it is an input, but a synthetic one, and if
    ! the two RNG streams ever diverge the gradients would differ for a reason
    ! that has nothing to do with cuEST.
    write(*,'(A)') ""
    call matrix_report("D (synthetic density)", h_den, nao)
    call dev_to_host(h_grad, d_dldr, ngrad)
    call array_report("dL/dR (angular momentum Lz gradient)", h_grad, ngrad)
    call dev_to_host(h_grad, d_dndr, ngrad)
    call array_report("dN/dR (nabla x gradient)", h_grad, ngrad)
    call dev_to_host(h_grad, d_dmdr, ngrad)
    call array_report("dM/dR (multipole 1 0 0 gradient)", h_grad, ngrad)

    ! ---- 12. teardown ------------------------------------------------------
    deallocate(h_grad)
    deallocate(h_den)
    call dev_free(d_dldr)
    call dev_free(d_dndr)
    call dev_free(d_dmdr)
    call dev_free(d_d)

    ist = cuestOEIntPlanDestroy(plan)
    call ws_free(ws_plan)
    ist = cuestAOPairListDestroy(pair_list)
    call ws_free(ws_pl)
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    call free_ao_shell_data(sd)
    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)

    write(*,'(A)') ""
    write(*,'(A)') "done."

contains

    !> The pair list takes HOST coordinates, so C_LOC needs a TARGET actual
    !  argument; wrapping it here keeps the main flow readable.
    subroutine make_pair_list()
        real(c_double), parameter :: TOL = 1.0d-14
        call cuest_check(cuestAOPairListCreateWorkspaceQuery(handle, basis, &
                         num_atoms, c_loc(xyz%xyz_cpu), TOL, pl_par, &
                         d_persist, d_temp, pair_list), &
                         "AOPairListCreateWorkspaceQuery")
        call ws_alloc(ws_pl, d_persist)
        call ws_alloc(ws_tmp, d_temp)
        call cuest_check(cuestAOPairListCreate(handle, basis, num_atoms, &
                         c_loc(xyz%xyz_cpu), TOL, pl_par, ws_pl, ws_tmp, &
                         pair_list), "cuestAOPairListCreate")
        call ws_free(ws_tmp)
    end subroutine make_pair_list

    !> Port of the sample's fill_nonsymmetric_matrix(): a full N x N matrix of
    !  standard normal deviates, generated by a Box-Muller transform of
    !  consecutive rand() values after srand(0). Every element draws its own
    !  pair, so unlike the symmetric variant the matrix has no symmetry.
    !
    !  Row-major flat storage, so element (i,j) with 0-based i,j lives at
    !  index i*N + j + 1.
    subroutine fill_nonsymmetric_matrix(a, n)
        real(c_double),     intent(out) :: a(:)
        integer(c_int64_t), intent(in)  :: n
        integer(c_int64_t) :: i, j
        real(c_double) :: u1, u2
        call c_srand(0_c_int)
        do i = 0_c_int64_t, n - 1_c_int64_t
            do j = 0_c_int64_t, n - 1_c_int64_t
                u1 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                u2 = (real(c_rand(), c_double) + 1.0d0) / RAND_DIV
                a(i*n + j + 1_c_int64_t) = sqrt(-2.0d0 * log(u1)) &
                                           * cos(2.0d0 * PI * u2)
            end do
        end do
    end subroutine fill_nonsymmetric_matrix

    !> Push `n` doubles from a host array to a device buffer. C_LOC needs a
    !  TARGET dummy, hence the wrapper.
    subroutine host_to_dev(dev, host, n)
        type(c_ptr),        intent(in) :: dev
        real(c_double),     intent(in), target :: host(:)
        integer(c_int64_t), intent(in) :: n
        call cuda_ck(cudaMemcpy(dev, c_loc(host), &
                     int(n, c_size_t) * 8_c_size_t, cudaMemcpyHostToDevice), &
                     "cudaMemcpy(H2D density)")
    end subroutine host_to_dev

end program property_gradients
