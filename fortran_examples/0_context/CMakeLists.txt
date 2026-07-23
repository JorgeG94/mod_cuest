# Ports for the 0_context sample group.
# add_fortran_example(<name> <name>.f90 ARGS @XYZ@ @GBS@)
# add_c_oracle(<name> ../oracle/<name>_oracle.c)
#
# None of these samples takes command-line arguments, so ARGS is omitted.

add_fortran_example(basic_usage
                    ${CMAKE_CURRENT_SOURCE_DIR}/basic_usage.f90)
add_c_oracle(basic_usage
             ${CMAKE_SOURCE_DIR}/oracle/basic_usage_oracle.c)

add_fortran_example(basic_multistream_usage
                    ${CMAKE_CURRENT_SOURCE_DIR}/basic_multistream_usage.f90)
add_c_oracle(basic_multistream_usage
             ${CMAKE_SOURCE_DIR}/oracle/basic_multistream_usage_oracle.c)

add_fortran_example(basic_multigpu_usage
                    ${CMAKE_CURRENT_SOURCE_DIR}/basic_multigpu_usage.f90)
add_c_oracle(basic_multigpu_usage
             ${CMAKE_SOURCE_DIR}/oracle/basic_multigpu_usage_oracle.c)

add_fortran_example(user_owned_resources
                    ${CMAKE_CURRENT_SOURCE_DIR}/user_owned_resources.f90)
add_c_oracle(user_owned_resources
             ${CMAKE_SOURCE_DIR}/oracle/user_owned_resources_oracle.c)

# Two of the oracles in this group need more than add_c_oracle's default
# (cuEST + cudart + m): the upstream multi-GPU sample is built on pthreads, and
# the user-owned-resources sample creates cuBLAS and cuSolver handles itself.
# The Fortran side already gets all three through cuest_fortran_common.
if(TARGET basic_multigpu_usage_oracle)
    target_link_libraries(basic_multigpu_usage_oracle PRIVATE Threads::Threads)
endif()
if(TARGET user_owned_resources_oracle)
    target_link_libraries(user_owned_resources_oracle
                          PRIVATE CUDA::cublas CUDA::cusolver)
endif()
