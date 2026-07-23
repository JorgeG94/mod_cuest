add_fortran_example(one_electron_integrals
                    ${CMAKE_CURRENT_SOURCE_DIR}/one_electron_integrals.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(one_electron_integrals
             ${CMAKE_SOURCE_DIR}/oracle/one_electron_integrals_oracle.c)

add_fortran_example(one_electron_gradients
                    ${CMAKE_CURRENT_SOURCE_DIR}/one_electron_gradients.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(one_electron_gradients
             ${CMAKE_SOURCE_DIR}/oracle/one_electron_gradients_oracle.c)

add_fortran_example(property_integrals
                    ${CMAKE_CURRENT_SOURCE_DIR}/property_integrals.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(property_integrals
             ${CMAKE_SOURCE_DIR}/oracle/property_integrals_oracle.c)

add_fortran_example(property_gradients
                    ${CMAKE_CURRENT_SOURCE_DIR}/property_gradients.f90
                    ARGS @XYZ@ @GBS@)
add_c_oracle(property_gradients
             ${CMAKE_SOURCE_DIR}/oracle/property_gradients_oracle.c)
