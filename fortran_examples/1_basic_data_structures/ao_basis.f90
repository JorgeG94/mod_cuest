! ============================================================================
!  ao_basis.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    ao_basis/main.c   (+ its basis_definition.h)
!
!  Builds a def2-SVP AO basis for water out of an explicit array of AO shells:
!  six shells on oxygen and three on each hydrogen, from exponents and
!  contraction coefficients hardcoded in the C sample's basis_definition.h.
!  Every shell is queried for its attributes, the totals are accumulated by
!  hand, and the finished AO basis handle is queried for the same quantities
!  so the two can be checked against each other.
!
!  Structure follows the C sample call for call:
!    handle -> AO shell parameters -> 12 x cuestAOShellCreate -> cuestQuery
!           -> AO basis (query -> allocate -> create) -> cuestQuery
!
!  As in the C sample the contraction coefficients go to cuEST unnormalised;
!  the normalisation in helper_ao_shells.h is deliberately not applied here.
!
!  Difference from the C sample: it prints the attributes in a form nothing can
!  parse, so each number is additionally emitted as an array/scalar report
!  section. The oracle emits the identical sections.
!
!  Usage:  ./ao_basis        (no arguments)
! ============================================================================
program ao_basis
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64, cuest_query_i32
    use cuest_sample_utils, only: cuest_check, scalar_report, array_report, &
                                  ws_alloc, ws_free
    use gbs_parser, only: atom_basis_t
    implicit none

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par  = c_null_ptr
    type(c_ptr) :: sh_par = c_null_ptr
    type(c_ptr) :: basis_par = c_null_ptr
    type(c_ptr) :: basis = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_basis, ws_tmp

    integer(c_int32_t), parameter :: IS_PURE = 1_c_int32_t

    !> The water molecule: 6 shells on O, 3 on each H.
    integer(c_int64_t), parameter :: NUM_ATOMS = 3_c_int64_t
    integer(c_int64_t), parameter :: NUM_SHELLS_TOTAL = 12_c_int64_t
    integer(c_int64_t), target :: num_shells_per_atom(3) = &
        [6_c_int64_t, 3_c_int64_t, 3_c_int64_t]

    type(atom_basis_t), target  :: o_basis, h_basis
    type(atom_basis_t), pointer :: ab => null()

    type(c_ptr), allocatable :: shells(:)

    !> Per-shell attributes, in shell order, kept so they can all be reported
    !  after the sample's own output has been written.
    real(c_double) :: rep_is_pure(12), rep_l(12), rep_nprim(12)
    real(c_double) :: rep_nao(12), rep_npure(12), rep_ncart(12)

    integer(c_int64_t) :: max_l = 0, nao_total = 0, nprim_total = 0
    integer(c_int64_t) :: npure_total = 0, ncart_total = 0
    integer(c_int64_t) :: max_l_from_shells = 0
    integer(c_int64_t) :: natom = 0, nshell = 0, nao = 0, ncart = 0, nprimitive = 0
    integer(c_int32_t) :: is_pure_basis = 0

    integer(c_int64_t) :: l, np, off
    integer(c_int32_t) :: q_is_pure
    integer(c_int64_t) :: q_l, q_nprim, q_nao, q_npure, q_ncart
    integer(c_int) :: ist
    integer :: n, i, count

    call fill_basis_definition()

    ! ---- 1. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    allocate(shells(NUM_SHELLS_TOTAL))
    shells = c_null_ptr

    ! ---- 2. the twelve AO shells -------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOSHELL_PARAMETERS, sh_par), &
                     "ParametersCreate(AO shell)")

    count = 0
    do n = 1, int(NUM_ATOMS)
        if (n == 1) then
            ab => o_basis
        else
            ab => h_basis
        end if
        do i = 1, int(num_shells_per_atom(n))
            count = count + 1
            l   = ab%shell_types(i)
            np  = ab%num_primitives(i)
            off = ab%primitive_offsets(i)                 ! 0-based, as in C
            call create_shell(IS_PURE, l, np, &
                              ab%exponents(off+1 : off+np), &
                              ab%coefficients(off+1 : off+np), shells(count))
        end do
    end do

    call cuest_check(cuestParametersDestroy(CUEST_AOSHELL_PARAMETERS, sh_par), &
                     "ParametersDestroy(AO shell)")

    ! ---- 3. query every shell and accumulate the totals ---------------------
    count = 0
    do n = 1, int(NUM_ATOMS)
        do i = 1, int(num_shells_per_atom(n))
            count = count + 1
            call cuest_check(cuest_query_i32(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_IS_PURE, q_is_pure), "query IS_PURE")
            call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_L, q_l), "query L")
            call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_NUM_PRIMITIVE, q_nprim), "query NUM_PRIMITIVE")
            call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_NUM_AO, q_nao), "query NUM_AO")
            call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_NUM_PURE, q_npure), "query NUM_PURE")
            call cuest_check(cuest_query_i64(handle, CUEST_AOSHELL, shells(count), &
                             CUEST_AOSHELL_NUM_CART, q_ncart), "query NUM_CART")

            if (n == 1) then
                write(*,'(A,I0,A)') "Oxygen Shell ", i, " (def2-SVP):"
            else
                write(*,'(A,I0,A)') "Hydrogen Shell ", i, " (def2-SVP):"
            end if
            if (q_is_pure /= 0) then
                write(*,'(A)') "Angular momentum:              spherical"
            else
                write(*,'(A)') "Angular momentum:              cartesian"
            end if
            write(*,'(A,I0)') "L:                             ", q_l
            write(*,'(A,I0)') "Number of primitives:          ", q_nprim
            write(*,'(A,I0)') "Number of basis functions:     ", q_nao
            write(*,'(A,I0)') "Number of pure functions:      ", q_npure
            write(*,'(A,I0)') "Number of cartesian functions: ", q_ncart
            write(*,'(A)') ""

            rep_is_pure(count) = real(q_is_pure, c_double)
            rep_l(count)       = real(q_l,       c_double)
            rep_nprim(count)   = real(q_nprim,   c_double)
            rep_nao(count)     = real(q_nao,     c_double)
            rep_npure(count)   = real(q_npure,   c_double)
            rep_ncart(count)   = real(q_ncart,   c_double)

            max_l = max(max_l, q_l)
            nao_total   = nao_total   + q_nao
            nprim_total = nprim_total + q_nprim
            npure_total = npure_total + q_npure
            ncart_total = ncart_total + q_ncart
        end do
    end do
    max_l_from_shells = max_l

    ! ---- 4. AO basis (query -> allocate -> create) --------------------------
    call cuest_check(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersCreate(basis)")
    call cuest_check(cuestAOBasisCreateWorkspaceQuery(handle, NUM_ATOMS, &
                     num_shells_per_atom, shells, basis_par, &
                     d_persist, d_temp, basis), "AOBasisCreateWorkspaceQuery")
    call ws_alloc(ws_basis, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestAOBasisCreate(handle, NUM_ATOMS, &
                     num_shells_per_atom, shells, basis_par, &
                     ws_basis, ws_tmp, basis), "cuestAOBasisCreate")
    call ws_free(ws_tmp)
    call cuest_check(cuestParametersDestroy(CUEST_AOBASIS_PARAMETERS, basis_par), &
                     "ParametersDestroy(basis)")

    ! The shell handles are no longer needed once the basis exists.
    do i = 1, int(NUM_SHELLS_TOTAL)
        call cuest_check(cuestAOShellDestroy(shells(i)), "cuestAOShellDestroy")
    end do
    deallocate(shells)

    ! ---- 5. query the finished basis ---------------------------------------
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_ATOM, natom), "query NUM_ATOM")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_SHELL, nshell), "query NUM_SHELL")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_AO, nao), "query NUM_AO")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_CART, ncart), "query NUM_CART")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_NUM_PRIMITIVE, nprimitive), "query NUM_PRIMITIVE")
    call cuest_check(cuest_query_i64(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_MAX_L, max_l), "query MAX_L")
    call cuest_check(cuest_query_i32(handle, CUEST_AOBASIS, basis, &
                     CUEST_AOBASIS_IS_PURE, is_pure_basis), "query IS_PURE")

    write(*,'(A)') "AO Basis from handle:"
    write(*,'(A,I6)') "natom      = ", natom
    write(*,'(A,I6)') "nshell     = ", nshell
    write(*,'(A,I6)') "nao        = ", nao
    write(*,'(A,I6)') "ncart      = ", ncart
    write(*,'(A,I6)') "nprimitive = ", nprimitive
    write(*,'(A,I6)') "max_L      = ", max_l
    if (is_pure_basis /= 0) then
        write(*,'(A)') "is_pure    =   true"
    else
        write(*,'(A)') "is_pure    =  false"
    end if

    ! ---- 6. report ---------------------------------------------------------
    call array_report("shell is_pure",        rep_is_pure, NUM_SHELLS_TOTAL)
    call array_report("shell L",              rep_l,       NUM_SHELLS_TOTAL)
    call array_report("shell num_primitives", rep_nprim,   NUM_SHELLS_TOTAL)
    call array_report("shell num_ao",         rep_nao,     NUM_SHELLS_TOTAL)
    call array_report("shell num_pure",       rep_npure,   NUM_SHELLS_TOTAL)
    call array_report("shell num_cart",       rep_ncart,   NUM_SHELLS_TOTAL)

    call scalar_report("shells max_L",       real(max_l_from_shells, c_double))
    call scalar_report("shells nao_total",   real(nao_total,   c_double))
    call scalar_report("shells nprim_total", real(nprim_total, c_double))
    call scalar_report("shells npure_total", real(npure_total, c_double))
    call scalar_report("shells ncart_total", real(ncart_total, c_double))

    call scalar_report("basis natom",      real(natom,      c_double))
    call scalar_report("basis nshell",     real(nshell,     c_double))
    call scalar_report("basis nao",        real(nao,        c_double))
    call scalar_report("basis ncart",      real(ncart,      c_double))
    call scalar_report("basis nprimitive", real(nprimitive, c_double))
    call scalar_report("basis max_L",      real(max_l,      c_double))
    call scalar_report("basis is_pure",    real(is_pure_basis, c_double))

    ! ---- 7. teardown -------------------------------------------------------
    ist = cuestAOBasisDestroy(basis)
    call ws_free(ws_basis)
    ist = cuestDestroy(handle)

contains

    !> The def2-SVP hydrogen and oxygen definitions of basis_definition.h,
    !  transcribed into the same layout the GBS parser produces (packed
    !  exponents/coefficients plus 0-based per-shell offsets).
    subroutine fill_basis_definition()
        h_basis%n_shells = 3_c_int64_t
        h_basis%shell_types       = [0_c_int64_t, 0_c_int64_t, 1_c_int64_t]
        h_basis%num_primitives    = [3_c_int64_t, 1_c_int64_t, 1_c_int64_t]
        h_basis%primitive_offsets = [0_c_int64_t, 3_c_int64_t, 4_c_int64_t]
        h_basis%exponents = [ &
            13.0107010d0, 1.9622572d0, 0.44453796d0, &
            0.12194962d0, &
            0.8000000d0]
        h_basis%coefficients = [ &
            0.019682158d0, 0.13796524d0, 0.47831935d0, &
            1.0d0, &
            1.0d0]

        o_basis%n_shells = 6_c_int64_t
        o_basis%shell_types       = [0_c_int64_t, 0_c_int64_t, 0_c_int64_t, &
                                     1_c_int64_t, 1_c_int64_t, 2_c_int64_t]
        o_basis%num_primitives    = [5_c_int64_t, 1_c_int64_t, 1_c_int64_t, &
                                     3_c_int64_t, 1_c_int64_t, 1_c_int64_t]
        o_basis%primitive_offsets = [0_c_int64_t, 5_c_int64_t, 6_c_int64_t, &
                                     7_c_int64_t, 10_c_int64_t, 11_c_int64_t]
        o_basis%exponents = [ &
            2266.1767785d0, 340.87010191d0, 77.363135167d0, &
            21.479644940d0, 6.6589433124d0, &
            0.80975975668d0, &
            0.25530772234d0, &
            17.721504317d0, 3.8635505440d0, 1.0480920883d0, &
            0.27641544411d0, &
            1.2d0]
        o_basis%coefficients = [ &
            -0.0053431809926d0, -0.039890039230d0, -0.17853911985d0, &
            -0.46427684959d0, -0.44309745172d0, &
            1.0d0, &
            1.0d0, &
            0.043394573193d0, 0.23094120765d0, 0.51375311064d0, &
            1.0d0, &
            1.0d0]
    end subroutine fill_basis_definition

    !> Wrapper that gives the exponent/coefficient slices the TARGET attribute
    !  C_LOC requires; array sections cannot be passed to C_LOC directly.
    subroutine create_shell(is_pure, l_in, np_in, expo, coef, shell)
        integer(c_int32_t), intent(in) :: is_pure
        integer(c_int64_t), intent(in) :: l_in, np_in
        real(c_double), intent(in), target :: expo(:), coef(:)
        type(c_ptr), intent(inout) :: shell
        call cuest_check(cuestAOShellCreate(handle, is_pure, l_in, np_in, &
                         c_loc(expo), c_loc(coef), sh_par, shell), &
                         "cuestAOShellCreate")
    end subroutine create_shell

end program ao_basis
