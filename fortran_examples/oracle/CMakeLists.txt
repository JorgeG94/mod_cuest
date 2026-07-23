# The C reference. It #includes the C samples' common/ helpers, so it can only
# be built when a CUDALibrarySamples checkout is available -- which CUEST_ROOT
# supplies automatically if the package was unpacked with the samples in place.
# Without it the Fortran examples still build; only the numeric comparison goes
# missing.
if(DEFINED CUEST_SAMPLES_COMMON_DIR AND EXISTS ${CUEST_SAMPLES_COMMON_DIR}
   AND DEFINED CUEST_INCLUDE_DIR AND EXISTS ${CUEST_INCLUDE_DIR})
    add_executable(one_electron_integrals_oracle one_electron_integrals_oracle.c)
    target_include_directories(one_electron_integrals_oracle
        PRIVATE ${CUEST_INCLUDE_DIR} ${CUEST_SAMPLES_COMMON_DIR})
    target_link_libraries(one_electron_integrals_oracle
        PRIVATE ${CUEST_LIBRARY} CUDA::cudart m)
    message(STATUS "C oracle: enabled")
else()
    message(STATUS "C oracle: DISABLED (needs the CUDALibrarySamples helpers; "
                   "set -DCUEST_SAMPLES_COMMON_DIR=<...>/c_examples/common)")
endif()
