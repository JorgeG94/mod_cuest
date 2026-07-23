add_fortran_example(one_electron_integrals
                    ${CMAKE_CURRENT_SOURCE_DIR}/one_electron_integrals.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(one_electron_integrals
             ${CMAKE_SOURCE_DIR}/oracle/one_electron_integrals_oracle.c)
