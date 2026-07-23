! ============================================================================
!  xc_grid.f90
!
!  Fortran port of
!    CUDALibrarySamples/cuEST/c_examples/examples/1_basic_data_structures/
!    xc_grid/main.c   (+ its molecule_definition.h)
!
!  Builds the pruned "GRID1" integration grid of Treutler and Ahlrichs
!  (J. Chem. Phys. 102, 346 (1995)) for a hardcoded water molecule: a 25-point
!  radial mesh on oxygen and a 20-point mesh on each hydrogen, each radial
!  shell carrying a Lebedev order chosen by the pruning scheme, assembled into
!  one cuestMolecularGrid_t.
!
!  Structure follows the C sample call for call:
!    handle -> per-atom radial quadrature + pruning -> cuestAtomGridCreate
!           -> molecular grid (query -> allocate -> create)
!
!  Two deliberate divergences from the C sample:
!    * xc_grid/main.c does not include helper_grid.h; it re-declares
!      build_ahlrichs_radial_quadrature verbatim. This port uses the shared
!      grid_helper version instead of duplicating it -- the arithmetic is
!      identical, expression for expression.
!    * the C computes the grid and exits without printing anything, so every
!      quantity it produces (the radial quadratures, the pruning arrays, and
!      the attributes of the finished grids) is emitted as a report section
!      here. The oracle emits the identical sections.
!
!  All three arrays handed to cuestAtomGridCreate are HOST memory; the API
!  documents radialNodes / radialWeights / numAngularPoints as being on the
!  CPU, and cuestMolecularGridCreate takes the host coordinates.
!
!  Usage:  ./xc_grid        (no arguments)
! ============================================================================
program xc_grid
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_query_i64
    use cuda_runtime
    use cuest_sample_utils, only: cuest_check, cuda_ck, scalar_report, &
                                  array_report, ws_alloc, ws_free
    use grid_helper, only: build_ahlrichs_radial_quadrature
    implicit none

    integer(c_int64_t), parameter :: NUM_ATOMS = 3_c_int64_t

    !> The hardcoded water molecule of molecule_definition.h. Coordinates are
    !  used exactly as written there -- no unit conversion is applied.
    real(c_double), target :: xyz_cpu(9) = [ &
         0.000000d0, -0.224906d0,  0.000000d0, &
         1.452350d0,  0.899624d0,  0.000000d0, &
        -1.452350d0,  0.899624d0,  0.000000d0]
    real(c_double), target :: charges_cpu(3) = [-8.0d0, -1.0d0, -1.0d0]
    character(len=2), parameter :: SYMBOLS(3) = [character(len=2) :: "O", "H", "H"]

    type(c_ptr) :: xyz_gpu = c_null_ptr, charges_gpu = c_null_ptr

    type(c_ptr) :: handle = c_null_ptr
    type(c_ptr) :: h_par = c_null_ptr
    type(c_ptr) :: ag_par = c_null_ptr
    type(c_ptr) :: mg_par = c_null_ptr
    type(c_ptr) :: molecular_grid = c_null_ptr
    type(c_ptr), allocatable :: atom_grid(:)

    type(cuestWorkspaceDescriptor_t) :: d_persist, d_temp
    type(cuestWorkspace_t) :: ws_grid, ws_tmp

    real(c_double),     allocatable, target :: radial_nodes(:), radial_weights(:)
    integer(c_int64_t), allocatable :: num_angular_points(:)
    real(c_double),     allocatable :: rep_angular(:)

    integer(c_int64_t) :: num_radial_points
    integer(c_int64_t) :: g_npoint, g_nradial, g_maxang
    real(c_double) :: radius
    character(len=64) :: lbl
    integer(c_int) :: ist
    integer :: n, i

    ! ---- 1. the molecule, mirrored to the device as the C helper does ------
    call cuda_ck(cudaMalloc(xyz_gpu, 9_c_size_t * 8_c_size_t), "cudaMalloc(xyz)")
    call cuda_ck(cudaMalloc(charges_gpu, 3_c_size_t * 8_c_size_t), &
                 "cudaMalloc(charges)")
    call cuda_ck(cudaMemcpy(xyz_gpu, c_loc(xyz_cpu), 9_c_size_t * 8_c_size_t, &
                 cudaMemcpyHostToDevice), "cudaMemcpy(xyz H2D)")
    call cuda_ck(cudaMemcpy(charges_gpu, c_loc(charges_cpu), &
                 3_c_size_t * 8_c_size_t, cudaMemcpyHostToDevice), &
                 "cudaMemcpy(charges H2D)")

    ! ---- 2. cuEST handle ---------------------------------------------------
    call cuest_check(cuestParametersCreate(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersCreate(handle)")
    call cuest_check(cuestCreate(h_par, handle), "cuestCreate")
    call cuest_check(cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, h_par), &
                     "ParametersDestroy(handle)")

    ! ---- 3. one pruned atom grid per atom ----------------------------------
    allocate(atom_grid(NUM_ATOMS))
    atom_grid = c_null_ptr

    do n = 1, int(NUM_ATOMS)

        ! Radial mesh size and atomic radius, per element.
        if (SYMBOLS(n) == "O") then
            num_radial_points = 25_c_int64_t
            radius = 0.90d0
        else    ! hydrogen
            num_radial_points = 20_c_int64_t
            radius = 0.80d0
        end if

        allocate(radial_nodes(num_radial_points), &
                 radial_weights(num_radial_points), &
                 num_angular_points(num_radial_points), &
                 rep_angular(num_radial_points))

        ! The Treutler-Ahlrichs pruning scheme, encoded per radial shell.
        if (SYMBOLS(n) == "O") then
            num_angular_points(1:8)   = 14_c_int64_t
            num_angular_points(9:12)  = 50_c_int64_t
            num_angular_points(13:int(num_radial_points)) = 110_c_int64_t
        else    ! hydrogen
            num_angular_points(1:6)   = 14_c_int64_t
            num_angular_points(7:10)  = 50_c_int64_t
            num_angular_points(11:int(num_radial_points)) = 50_c_int64_t
        end if

        call cuest_check(cuestParametersCreate(CUEST_ATOMGRID_PARAMETERS, ag_par), &
                         "ParametersCreate(atom grid)")
        call build_ahlrichs_radial_quadrature(num_radial_points, radius, &
                                              radial_nodes, radial_weights)
        call cuest_check(cuestAtomGridCreate(handle, num_radial_points, &
                         c_loc(radial_nodes), c_loc(radial_weights), &
                         num_angular_points, ag_par, atom_grid(n)), &
                         "cuestAtomGridCreate")
        call cuest_check(cuestParametersDestroy(CUEST_ATOMGRID_PARAMETERS, ag_par), &
                         "ParametersDestroy(atom grid)")

        ! Report the quadrature before the buffers go away.
        do i = 1, int(num_radial_points)
            rep_angular(i) = real(num_angular_points(i), c_double)
        end do
        write(lbl,'(A,I0,A)') "atom ", n, " radial nodes"
        call array_report(trim(lbl), radial_nodes, num_radial_points)
        write(lbl,'(A,I0,A)') "atom ", n, " radial weights"
        call array_report(trim(lbl), radial_weights, num_radial_points)
        write(lbl,'(A,I0,A)') "atom ", n, " num angular points"
        call array_report(trim(lbl), rep_angular, num_radial_points)

        deallocate(radial_nodes, radial_weights, num_angular_points, rep_angular)
    end do

    ! ---- 4. the molecular grid (query -> allocate -> create) ---------------
    call cuest_check(cuestParametersCreate(CUEST_MOLECULARGRID_PARAMETERS, mg_par), &
                     "ParametersCreate(molecular grid)")
    call cuest_check(cuestMolecularGridCreateWorkspaceQuery(handle, NUM_ATOMS, &
                     atom_grid, c_loc(xyz_cpu), mg_par, d_persist, d_temp, &
                     molecular_grid), "MolecularGridCreateWorkspaceQuery")
    call ws_alloc(ws_grid, d_persist)
    call ws_alloc(ws_tmp, d_temp)
    call cuest_check(cuestMolecularGridCreate(handle, NUM_ATOMS, atom_grid, &
                     c_loc(xyz_cpu), mg_par, ws_grid, ws_tmp, molecular_grid), &
                     "cuestMolecularGridCreate")
    call cuest_check(cuestParametersDestroy(CUEST_MOLECULARGRID_PARAMETERS, mg_par), &
                     "ParametersDestroy(molecular grid)")
    call ws_free(ws_tmp)

    ! ---- 5. report the grids themselves ------------------------------------
    do n = 1, int(NUM_ATOMS)
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, atom_grid(n), &
                         CUEST_ATOMGRID_NUM_POINT, g_npoint), "query ATOMGRID_NUM_POINT")
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, atom_grid(n), &
                         CUEST_ATOMGRID_NUM_RADIAL_POINT, g_nradial), &
                         "query ATOMGRID_NUM_RADIAL_POINT")
        call cuest_check(cuest_query_i64(handle, CUEST_ATOMGRID, atom_grid(n), &
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
    do n = 1, int(NUM_ATOMS)
        ist = cuestAtomGridDestroy(atom_grid(n))
    end do
    deallocate(atom_grid)
    ist = cuestDestroy(handle)
    if (c_associated(xyz_gpu))     ist = cudaFree(xyz_gpu)
    if (c_associated(charges_gpu)) ist = cudaFree(charges_gpu)

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

end program xc_grid
