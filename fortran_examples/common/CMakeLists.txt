# The parser self-test lives with the helpers it exercises. It creates no cuEST
# handle, so unlike every other target here it runs on any CUDA GPU.
add_fortran_example(test_parsers ${CMAKE_CURRENT_SOURCE_DIR}/../test_parsers.f90
                    ARGS @XYZ@ @GBS@)
