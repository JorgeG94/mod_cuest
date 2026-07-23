# Ports for the 5_effective_core_potentials sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)

add_fortran_example(ecp_integrals
                    ${CMAKE_CURRENT_SOURCE_DIR}/ecp_integrals.f90
                    ARGS @XYZ_ECP@ @GBS@ @ECP_GBS@)
add_c_oracle(ecp_integrals
             ${CMAKE_SOURCE_DIR}/oracle/ecp_integrals_oracle.c)

add_fortran_example(ecp_gradients
                    ${CMAKE_CURRENT_SOURCE_DIR}/ecp_gradients.f90
                    ARGS @XYZ_ECP@ @GBS@ @ECP_GBS@)
add_c_oracle(ecp_gradients
             ${CMAKE_SOURCE_DIR}/oracle/ecp_gradients_oracle.c)
