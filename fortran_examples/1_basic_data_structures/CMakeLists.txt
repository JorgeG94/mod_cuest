# Ports for the 1_basic_data_structures sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)
#
# Targets are named after the C sample DIRECTORY, so `ao_shells` and
# `ecp_shells` even though NVIDIA's executables for those two are called
# `ao_shell` / `ecp_shell`.

add_fortran_example(ao_basis
                    ${CMAKE_CURRENT_SOURCE_DIR}/ao_basis.f90)
add_c_oracle(ao_basis
             ${CMAKE_SOURCE_DIR}/oracle/ao_basis_oracle.c)

add_fortran_example(ao_shells
                    ${CMAKE_CURRENT_SOURCE_DIR}/ao_shells.f90)
add_c_oracle(ao_shells
             ${CMAKE_SOURCE_DIR}/oracle/ao_shells_oracle.c)

add_fortran_example(ao_basis_general
                    ${CMAKE_CURRENT_SOURCE_DIR}/ao_basis_general.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(ao_basis_general
             ${CMAKE_SOURCE_DIR}/oracle/ao_basis_general_oracle.c)

add_fortran_example(ecp_shells
                    ${CMAKE_CURRENT_SOURCE_DIR}/ecp_shells.f90)
add_c_oracle(ecp_shells
             ${CMAKE_SOURCE_DIR}/oracle/ecp_shells_oracle.c)

add_fortran_example(ecp_atom
                    ${CMAKE_CURRENT_SOURCE_DIR}/ecp_atom.f90
                    ARGS @XYZ_ECP@ @ECP_GBS@)
add_c_oracle(ecp_atom
             ${CMAKE_SOURCE_DIR}/oracle/ecp_atom_oracle.c)

add_fortran_example(xc_grid
                    ${CMAKE_CURRENT_SOURCE_DIR}/xc_grid.f90)
add_c_oracle(xc_grid
             ${CMAKE_SOURCE_DIR}/oracle/xc_grid_oracle.c)

add_fortran_example(xc_grid_general
                    ${CMAKE_CURRENT_SOURCE_DIR}/xc_grid_general.f90
                    ARGS @XYZ@)
add_c_oracle(xc_grid_general
             ${CMAKE_SOURCE_DIR}/oracle/xc_grid_general_oracle.c)
