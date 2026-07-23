# Ports for the 3_density_fitting sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)

add_fortran_example(core_df_jk
                    ${CMAKE_CURRENT_SOURCE_DIR}/core_df_jk.f90
                    ARGS @XYZ@ @GBS@ @AUX_GBS@)
add_c_oracle(core_df_jk
             ${CMAKE_SOURCE_DIR}/oracle/core_df_jk_oracle.c)

add_fortran_example(core_df_jk_gradients
                    ${CMAKE_CURRENT_SOURCE_DIR}/core_df_jk_gradients.f90
                    ARGS @XYZ@ @GBS@ @AUX_GBS@)
add_c_oracle(core_df_jk_gradients
             ${CMAKE_SOURCE_DIR}/oracle/core_df_jk_gradients_oracle.c)

add_fortran_example(df_mo_integrals
                    ${CMAKE_CURRENT_SOURCE_DIR}/df_mo_integrals.f90
                    ARGS @XYZ@ @GBS@ @AUX_GBS@)
add_c_oracle(df_mo_integrals
             ${CMAKE_SOURCE_DIR}/oracle/df_mo_integrals_oracle.c)

add_fortran_example(nonsymmetric_core_df_k
                    ${CMAKE_CURRENT_SOURCE_DIR}/nonsymmetric_core_df_k.f90
                    ARGS @XYZ@ @GBS@ @AUX_GBS@)
add_c_oracle(nonsymmetric_core_df_k
             ${CMAKE_SOURCE_DIR}/oracle/nonsymmetric_core_df_k_oracle.c)
