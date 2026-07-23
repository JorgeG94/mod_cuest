! ============================================================================
!  grid_helper.f90 -- Fortran port of common/helper_grid.h
!
!  Three pieces, in increasing order of cuEST involvement:
!
!    symbol_to_ahlrichs_radius     Ahlrichs radius (bohr) for an element
!                                  symbol; 1.0 for anything past Kr.
!    build_ahlrichs_radial_quadrature
!                                  Treutler-Ahlrichs M4 radial quadrature.
!                                  Pure arithmetic, no cuEST, no device memory.
!    form_direct_product_atom_grid Builds one cuestAtomGrid_t per atom: an
!                                  unpruned numRadial x numAngular direct
!                                  product grid on the Ahlrichs radial mesh.
!
!  Reference: O. Treutler and R. Ahlrichs, J. Chem. Phys. 102, 346 (1995).
!
!  Host/device note: cuestAtomGridCreate documents radialNodes, radialWeights
!  and numAngularPoints as CPU arrays (see include/cuest/grid/atom_grid_api.h),
!  and the C helper passes plain malloc'd buffers. They are therefore ordinary
!  Fortran host arrays here -- the two double arrays go through C_LOC, and
!  numAngularPoints is passed by reference because the binding declares it
!  dimension(*). Nothing in this module touches device memory.
! ============================================================================
module grid_helper
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_sample_utils, only: cuest_check
    use xyz_parser, only: parsed_xyz_t
    implicit none
    private

    public :: atom_grid_data_t, form_direct_product_atom_grid, free_atom_grid_data
    public :: symbol_to_ahlrichs_radius, build_ahlrichs_radial_quadrature

    !> The cuestAtomGrid_t array the molecular grid is built from, plus the
    !  quadrature sizes it was built with.
    type :: atom_grid_data_t
        integer(c_int64_t) :: num_atoms = 0
        integer(c_int64_t) :: num_radial_points = 0
        integer(c_int64_t) :: num_angular_points = 0
        type(c_ptr), allocatable :: grids(:)     !< num_atoms cuestAtomGrid_t
    end type atom_grid_data_t

    !> Same literal as ao_shells.f90, and the value of M_PI the C helper uses.
    real(c_double), parameter :: PI = 3.14159265358979323846d0

    !> Exponent of the (1+x) factor in the Treutler-Ahlrichs M4 mapping.
    real(c_double), parameter :: ALPHA = 0.6d0

    !> H .. Kr, index 0 being the "X" dummy the C table carries.
    character(len=2), parameter :: AHLRICHS_ELEMENTS(0:36) = [character(len=2) :: &
        "X",                                                                   &
        "H",  "HE",                                                            &
        "LI", "BE", "B",  "C",  "N",  "O",  "F",  "NE",                        &
        "NA", "MG", "AL", "SI", "P",  "S",  "CL", "AR",                        &
        "K",  "CA", "SC", "TI", "V",  "CR", "MN", "FE", "CO", "NI", "CU",      &
        "ZN", "GA", "GE", "AS", "SE", "BR", "KR"]

    real(c_double), parameter :: AHLRICHS_RADII(0:36) = [ &
        1.00d0,                                                                &
        0.80d0, 0.90d0,                                                        &
        1.80d0, 1.40d0, 1.30d0, 1.10d0, 0.90d0, 0.90d0, 0.90d0, 0.90d0,        &
        1.40d0, 1.30d0, 1.30d0, 1.20d0, 1.10d0, 1.00d0, 1.00d0, 1.00d0,        &
        1.50d0, 1.40d0, 1.30d0, 1.20d0, 1.20d0, 1.20d0, 1.20d0, 1.20d0,        &
        1.20d0, 1.10d0, 1.10d0, 1.10d0, 1.10d0, 1.00d0, 0.90d0, 0.90d0,        &
        0.90d0, 0.90d0]

contains

    !> Ahlrichs radius for an element symbol; 1.0 for anything not tabulated.
    !
    !  The C helper compares against an uppercase table with strcmp, and the XYZ
    !  parser upcases every symbol it reads, so a plain comparison matches. The
    !  1.0 fallback for Z > 36 is the C behaviour, kept deliberately.
    pure function symbol_to_ahlrichs_radius(symbol) result(r)
        character(*), intent(in) :: symbol
        real(c_double) :: r
        integer :: i
        r = 1.0d0
        do i = 0, 36
            if (symbol == AHLRICHS_ELEMENTS(i)) then
                r = AHLRICHS_RADII(i)
                return
            end if
        end do
    end function symbol_to_ahlrichs_radius

    !> Treutler-Ahlrichs M4 radial quadrature on npoint points for radius rad.
    !
    !  Direct port of build_ahlrichs_radial_quadrature(). The C loop runs
    !  i = 1..npoint and stores into [npoint-i], i.e. it fills the arrays back
    !  to front so nodes come out ascending; the Fortran index is npoint-i+1.
    !  Expression order is preserved so the two agree bit for bit.
    !
    !  nodes and weights must each be at least npoint long.
    pure subroutine build_ahlrichs_radial_quadrature(npoint, rad, nodes, weights)
        integer(c_int64_t), intent(in)  :: npoint
        real(c_double),     intent(in)  :: rad
        real(c_double),     intent(out) :: nodes(:), weights(:)
        real(c_double) :: z, x, y, u, v, r, w, np1
        integer :: i, n

        n = int(npoint)
        np1 = real(npoint, c_double) + 1.0d0
        do i = 1, n
            z = real(i, c_double) * PI / np1
            x = cos(z)
            y = sin(z)
            u = log((1.0d0 - x) / 2.0d0)
            v = (1.0d0 + x)**ALPHA / log(2.0d0)
            r = - rad * v * u
            w = PI / np1 * y * rad * v &
                * (-ALPHA * u / (1.0d0 + x) + 1.0d0 / (1.0d0 - x)) * r * r
            nodes(n - i + 1)   = r
            weights(n - i + 1) = w
        end do
    end subroutine build_ahlrichs_radial_quadrature

    !> Build one unpruned direct-product atom grid per atom of the molecule.
    !
    !  Mirrors formDirectProductAtomGrid(): one shared atom-grid parameters
    !  object, one shared angular-point array (constant, so every radial shell
    !  gets the same Lebedev order), and a fresh radial quadrature per atom
    !  scaled by that element's Ahlrichs radius.
    subroutine form_direct_product_atom_grid(handle, x, num_radial_points, &
                                             num_angular_points, gd)
        type(c_ptr),            intent(in)  :: handle
        type(parsed_xyz_t),     intent(in)  :: x
        integer(c_int64_t),     intent(in)  :: num_radial_points
        integer(c_int64_t),     intent(in)  :: num_angular_points
        type(atom_grid_data_t), intent(out) :: gd

        real(c_double), allocatable :: nodes(:), weights(:)
        integer(c_int64_t), allocatable :: nang(:)
        type(c_ptr) :: ag_par
        real(c_double) :: radius
        integer :: n, nat, nrad

        nat  = int(x%num_atoms)
        nrad = int(num_radial_points)

        gd%num_atoms          = x%num_atoms
        gd%num_radial_points  = num_radial_points
        gd%num_angular_points = num_angular_points

        allocate(gd%grids(nat))
        gd%grids = c_null_ptr

        ag_par = c_null_ptr
        call cuest_check(cuestParametersCreate(CUEST_ATOMGRID_PARAMETERS, ag_par), &
                         "ParametersCreate(atom grid)")

        allocate(nodes(nrad), weights(nrad), nang(nrad))
        nang = num_angular_points

        do n = 1, nat
            radius = symbol_to_ahlrichs_radius(x%symbols(n))
            call build_ahlrichs_radial_quadrature(num_radial_points, radius, &
                                                  nodes, weights)
            call create_atom_grid(handle, num_radial_points, nodes, weights, &
                                  nang, ag_par, gd%grids(n))
        end do

        call cuest_check(cuestParametersDestroy(CUEST_ATOMGRID_PARAMETERS, ag_par), &
                         "ParametersDestroy(atom grid)")

        deallocate(nodes, weights, nang)
    end subroutine form_direct_product_atom_grid

    !> Wrapper that gives the node/weight arrays the TARGET attribute C_LOC
    !  requires (same trick as ao_shells.f90 :: create_shell). All three arrays
    !  are HOST memory: cuestAtomGridCreate documents them as "on the CPU".
    subroutine create_atom_grid(handle, npoint, nodes, weights, nang, par, grid)
        type(c_ptr),        intent(in)         :: handle, par
        integer(c_int64_t), intent(in)         :: npoint
        real(c_double),     intent(in), target :: nodes(:), weights(:)
        integer(c_int64_t), intent(in)         :: nang(:)
        type(c_ptr),        intent(inout)      :: grid
        call cuest_check(cuestAtomGridCreate(handle, npoint, c_loc(nodes), &
                         c_loc(weights), nang, par, grid), "cuestAtomGridCreate")
    end subroutine create_atom_grid

    subroutine free_atom_grid_data(gd)
        type(atom_grid_data_t), intent(inout) :: gd
        integer(c_int) :: ist
        integer :: i
        if (allocated(gd%grids)) then
            do i = 1, size(gd%grids)
                if (c_associated(gd%grids(i))) ist = cuestAtomGridDestroy(gd%grids(i))
            end do
            deallocate(gd%grids)
        end if
        gd%num_atoms          = 0
        gd%num_radial_points  = 0
        gd%num_angular_points = 0
    end subroutine free_atom_grid_data

end module grid_helper
