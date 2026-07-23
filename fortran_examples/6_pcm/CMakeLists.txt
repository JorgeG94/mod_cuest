# Ports for the 6_pcm sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)

add_fortran_example(pcm_potential
                    ${CMAKE_CURRENT_SOURCE_DIR}/pcm_potential.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(pcm_potential
             ${CMAKE_SOURCE_DIR}/oracle/pcm_potential_oracle.c)

add_fortran_example(pcm_gradients
                    ${CMAKE_CURRENT_SOURCE_DIR}/pcm_gradients.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(pcm_gradients
             ${CMAKE_SOURCE_DIR}/oracle/pcm_gradients_oracle.c)
