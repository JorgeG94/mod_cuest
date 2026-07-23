# Ports for the 4_exchange_correlation sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)

add_fortran_example(local_xc_potential
    ${CMAKE_CURRENT_SOURCE_DIR}/local_xc_potential.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(local_xc_potential
    ${CMAKE_SOURCE_DIR}/oracle/local_xc_potential_oracle.c)

add_fortran_example(local_xc_gradient
    ${CMAKE_CURRENT_SOURCE_DIR}/local_xc_gradient.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(local_xc_gradient
    ${CMAKE_SOURCE_DIR}/oracle/local_xc_gradient_oracle.c)

add_fortran_example(nonlocal_xc_potential
    ${CMAKE_CURRENT_SOURCE_DIR}/nonlocal_xc_potential.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(nonlocal_xc_potential
    ${CMAKE_SOURCE_DIR}/oracle/nonlocal_xc_potential_oracle.c)

add_fortran_example(nonlocal_xc_gradient
    ${CMAKE_CURRENT_SOURCE_DIR}/nonlocal_xc_gradient.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(nonlocal_xc_gradient
    ${CMAKE_SOURCE_DIR}/oracle/nonlocal_xc_gradient_oracle.c)

add_fortran_example(advanced_local_xc_potential
    ${CMAKE_CURRENT_SOURCE_DIR}/advanced_local_xc_potential.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(advanced_local_xc_potential
    ${CMAKE_SOURCE_DIR}/oracle/advanced_local_xc_potential_oracle.c)

add_fortran_example(advanced_local_xc_gradient
    ${CMAKE_CURRENT_SOURCE_DIR}/advanced_local_xc_gradient.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(advanced_local_xc_gradient
    ${CMAKE_SOURCE_DIR}/oracle/advanced_local_xc_gradient_oracle.c)
