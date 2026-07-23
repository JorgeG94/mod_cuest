! ============================================================================
!  xc_grid_general.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    xc_grid_general/main.c
!
!  Builds a basic unpruned (75, 302) integration grid for an arbitrary molecule
!  using the grid helper, then assembles the per-atom grids into one
!  cuestMolecularGrid_t. This molecular grid handle is what exchange-correlation
!  evaluation in cuEST is built on.
!
!  Structure follows the C sample call for call:
!    handle -> formDirectProductAtomGrid(75, 302)
!           -> molecular grid (query -> allocate -> create)
!
!  Difference from the C sample: it builds the grid and exits without printing
!  anything, so the workspace sizes and the attributes of the finished grids are
!  emitted as report sections here. The oracle emits the identical sections.
!
!  The coordinates handed to cuestMolecularGridCreate are the HOST array, as in
!  the C sample; everything the grid helper passes to cuEST is host memory too.
!
!  Usage:  ./xc_grid_general <xyz_file>
! ============================================================================
program xc_grid_general
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuest_sample_utils, only: cuest_check, scalar_report, ws_alloc, ws_free, &
                                  arg, require_args
    use xyz_parser
    use grid_helper
    implicit none

    integer(c_int64_t), parameter :: NUM_RADIAL_POINTS  = 75_c_int64_t
    integer(c_int64_t), parameter :: NUM_ANGULAR_POINTS = 302_c_int64_t

    type(parsed_xyz_t),     target :: xyz
    type(atom_grid_data_t), target :: gd

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr
    type(c_ptr) :: mg_par = c_null_ptr
    type(c_ptr) :: molecular_grid = c_null_ptr

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_grid, ws_tmp

    integer(c_int64_t) :: num_atoms
    integer(c_int64_t) :: g_npoint, g_nradial, g_maxang
    integer(c_size_t)  :: ws_p_host, ws_p_dev, ws_t_host, ws_t_dev
    character(len=64) :: lbl
    integer(c_int) :: ist
    integer :: n

    call require_args(1, "<xyz_file>")

    ! ---- 1. parse the geometry ---------------------------------------------
    call parse_xyz_file(arg(1), ANGSTROM_TO_BOHR, xyz)
    num_atoms = xyz%num_atoms

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. one unpruned (75, 302) atom grid per atom ----------------------
    call form_direct_product_atom_grid(handle, xyz, NUM_RADIAL_POINTS, &
                                       NUM_ANGULAR_POINTS, gd)

    ! ---- 4. the molecular grid (query -> allocate -> create) ---------------
    call cuest_check(cuestParametersCreate(CUEST_MOLECULARGRID_PARAMETERS, mg_par), &
                     "ParametersCreate(molecular grid)")
    call cuest_check(cuestMolecularGridCreateWorkspaceQuery(handle, num_atoms, &
                     gd%grids, c_loc(xyz%xyz_cpu), mg_par, d_persist, d_temp, &
                     molecular_grid), "MolecularGridCreateWorkspaceQuery")

    ws_p_host = d_persist%hostBufferSizeInBytes
    ws_p_dev  = d_persist%deviceBufferSizeInBytes
    ws_t_host = d_temp%hostBufferSizeInBytes
    ws_t_dev  = d_temp%deviceBufferSizeInBytes

    call ws_alloc(ws_grid, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestMolecularGridCreate(handle, num_atoms, gd%grids, &
                     c_loc(xyz%xyz_cpu), mg_par, ws_grid, ws_tmp, &
                     molecular_grid), "cuestMolecularGridCreate")
    call cuest_check(cuestParametersDestroy(CUEST_MOLECULARGRID_PARAMETERS, mg_par), &
                     "ParametersDestroy(molecular grid)")
    call ws_free(ws_tmp)

    ! ---- 5. report ---------------------------------------------------------
    call scalar_report("num atoms", real(num_atoms, c_double))
    call scalar_report("workspace persistent host bytes", real(ws_p_host, c_double))
    call scalar_report("workspace persistent device bytes", real(ws_p_dev, c_double))
    call scalar_report("workspace temporary host bytes", real(ws_t_host, c_double))
    call scalar_report("workspace temporary device bytes", real(ws_t_dev, c_double))

    do n = 1, int(num_atoms)
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, gd%grids(n), &
                         CUEST_ATOMGRID_NUM_POINT, g_npoint), "query ATOMGRID_NUM_POINT")
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, gd%grids(n), &
                         CUEST_ATOMGRID_NUM_RADIAL_POINT, g_nradial), &
                         "query ATOMGRID_NUM_RADIAL_POINT")
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, gd%grids(n), &
                         CUEST_ATOMGRID_MAX_ANGULAR_POINT, g_maxang), &
                         "query ATOMGRID_MAX_ANGULAR_POINT")
        write(lbl,'(A,I0,A)') "atom ", n, " grid num_point"
        call scalar_report(trim(lbl), real(g_npoint, c_double))
        write(lbl,'(A,I0,A)') "atom ", n, " grid num_radial_point"
        call scalar_report(trim(lbl), real(g_nradial, c_double))
        write(lbl,'(A,I0,A)') "atom ", n, " grid max_angular_point"
        call scalar_report(trim(lbl), real(g_maxang, c_double))
    end do

    call report_molecular_grid()

    ! ---- 6. teardown -------------------------------------------------------
    ist = cuestMolecularGridDestroy(molecular_grid)
    call ws_free(ws_grid)
    call free_atom_grid_data(gd)
    ist = cuestDestroy(handle)
    call free_parsed_xyz(xyz)

contains

    !> The six documented molecular-grid attributes.
    subroutine report_molecular_grid()
        integer(c_int64_t) :: v
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_NUM_ATOM, v), "query MG_NUM_ATOM")
        call scalar_report("molecular grid num_atom", real(v, c_double))
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_NUM_POINT, v), "query MG_NUM_POINT")
        call scalar_report("molecular grid num_point", real(v, c_double))
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_MAX_POINT, v), "query MG_MAX_POINT")
        call scalar_report("molecular grid max_point", real(v, c_double))
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_NUM_RADIAL_POINT, v), "query MG_NUM_RADIAL")
        call scalar_report("molecular grid num_radial_point", real(v, c_double))
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_MAX_RADIAL_POINT, v), "query MG_MAX_RADIAL")
        call scalar_report("molecular grid max_radial_point", real(v, c_double))
        call cuest_check(cuest_query_i64(handle, CUEST_MOLECULARGRID, molecular_grid, &
                         CUEST_MOLECULARGRID_MAX_ANGULAR_POINT, v), "query MG_MAX_ANGULAR")
        call scalar_report("molecular grid max_angular_point", real(v, c_double))
    end subroutine report_molecular_grid

end program xc_grid_general
