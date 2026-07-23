# CMake build for the Fortran ports of the cuEST samples.
#
# Deliberately mirrors the UX of NVIDIA's c_examples build, so the same muscle
# memory works:
#
#   cmake -S . -B build -DCUEST_LIB_DIR=<pkg>/lib -DCUEST_INCLUDE_DIR=<pkg>/include
#   cmake --build build -j
#   ./run_all.sh build
#
# All executables land in build/bin, which keeps run_all.sh trivial.
cmake_minimum_required(VERSION 3.20)

project(cuest_fortran_examples LANGUAGES Fortran C)

find_package(CUDAToolkit REQUIRED)
find_package(Threads REQUIRED)

# ---------------------------------------------------------------------------
# cuEST location
#
# One variable is enough: point CUEST_ROOT at an unpacked cuEST package and
# everything else is derived from it.
#
#   -DCUEST_ROOT=<pkg>   ->  <pkg>/include
#                            <pkg>/lib
#                            <pkg>/CUDALibrarySamples/cuEST/c_examples/common
#
# The individual variables still work if a layout is unusual: any that is set
# explicitly wins over the derived value. NVIDIA's own CUEST_INCLUDE_DIR /
# CUEST_LIB_DIR spellings are kept so their command lines transfer unchanged.
#
# Note that unlike the C examples, the Fortran bindings are pre-generated, so
# headers are NOT needed to build the samples -- only the library is. The
# include directory matters only for the C reference oracle.
# ---------------------------------------------------------------------------
if(DEFINED CUEST_ROOT)
    get_filename_component(CUEST_ROOT "${CUEST_ROOT}" ABSOLUTE)
    if(NOT EXISTS ${CUEST_ROOT})
        message(FATAL_ERROR "CUEST_ROOT does not exist: ${CUEST_ROOT}")
    endif()
    if(NOT DEFINED CUEST_LIB_DIR)
        set(CUEST_LIB_DIR ${CUEST_ROOT}/lib)
    endif()
    if(NOT DEFINED CUEST_INCLUDE_DIR AND EXISTS ${CUEST_ROOT}/include)
        set(CUEST_INCLUDE_DIR ${CUEST_ROOT}/include)
    endif()
    if(NOT DEFINED CUEST_SAMPLES_COMMON_DIR AND
       EXISTS ${CUEST_ROOT}/CUDALibrarySamples/cuEST/c_examples/common)
        set(CUEST_SAMPLES_COMMON_DIR
            ${CUEST_ROOT}/CUDALibrarySamples/cuEST/c_examples/common)
    endif()
    message(STATUS "cuEST root: ${CUEST_ROOT}")
endif()

if(NOT DEFINED CUEST_LIB_DIR)
    message(FATAL_ERROR
        "Neither CUEST_ROOT nor CUEST_LIB_DIR is set.\n"
        "Re-run cmake with:  -DCUEST_ROOT=<path to the unpacked cuEST package>\n"
        "(or -DCUEST_LIB_DIR=<...> to point at the library directory directly)")
endif()

# Support both <lib_dir>/libcuest.so and <lib_dir>/<cuda_major>/libcuest.so
if(EXISTS ${CUEST_LIB_DIR}/libcuest.so)
    set(CUEST_LIBRARY ${CUEST_LIB_DIR}/libcuest.so)
elseif(EXISTS ${CUEST_LIB_DIR}/${CUDAToolkit_VERSION_MAJOR}/libcuest.so)
    set(CUEST_LIBRARY ${CUEST_LIB_DIR}/${CUDAToolkit_VERSION_MAJOR}/libcuest.so)
else()
    message(FATAL_ERROR "cuest library not found under ${CUEST_LIB_DIR}")
endif()
message(STATUS "cuEST library: ${CUEST_LIBRARY}")

set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--allow-shlib-undefined")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# ---------------------------------------------------------------------------
# The shared Fortran layer: the cuEST and CUDA bindings plus the ports of
# c_examples/common. CMake scans Fortran source for MODULE/USE and works out
# the compile order itself, so the sources are just listed.
# ---------------------------------------------------------------------------
add_library(cuest_fortran_common STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../cudafort/cuda_runtime.f90
    ${CMAKE_CURRENT_SOURCE_DIR}/../cudafort/cuda_helpers.f90
    ${CMAKE_CURRENT_SOURCE_DIR}/../cuest.f90
    ${CMAKE_CURRENT_SOURCE_DIR}/../cuest_helpers.f90
    common/cuest_sample_utils.f90
    common/xyz_parser.f90
    common/gbs_parser.f90
    common/ao_shells.f90
)
target_link_libraries(cuest_fortran_common
    PUBLIC
        ${CUEST_LIBRARY}
        CUDA::cudart
        CUDA::cublas
        CUDA::cusolver
        Threads::Threads
)
target_include_directories(cuest_fortran_common
    PUBLIC ${CMAKE_Fortran_MODULE_DIRECTORY})

# ---------------------------------------------------------------------------
# add_fortran_example(<name> <source> [ARGS ...])
#
# ARGS records how the example is invoked, so the same definition drives both
# the CTest registration and (via the generated manifest) run_all.sh. Tokens
# @XYZ@ / @GBS@ / @AUX_GBS@ / @XYZ_ECP@ / @ECP_GBS@ expand to the bundled data.
# ---------------------------------------------------------------------------
# A GLOBAL property, not a cache variable: cache values cannot contain the
# newlines the manifest needs.
set_property(GLOBAL PROPERTY CUEST_FORTRAN_MANIFEST "")

function(add_fortran_example NAME SOURCE)
    cmake_parse_arguments(AE "" "" "ARGS" ${ARGN})
    add_executable(${NAME} ${SOURCE})
    target_link_libraries(${NAME} PRIVATE cuest_fortran_common)
    string(REPLACE ";" " " _args "${AE_ARGS}")
    set_property(GLOBAL APPEND PROPERTY CUEST_FORTRAN_MANIFEST "${NAME}|${_args}")
endfunction()

add_subdirectory(common)
add_subdirectory(2_one_electron_integrals)
add_subdirectory(oracle)

# A manifest of "name|args" that run_all.sh reads, so adding an example needs
# no edit to the run script.
get_property(_manifest GLOBAL PROPERTY CUEST_FORTRAN_MANIFEST)
list(REMOVE_ITEM _manifest "")
list(JOIN _manifest "\n" _manifest_text)
file(GENERATE OUTPUT ${CMAKE_BINARY_DIR}/examples.manifest
     CONTENT "${_manifest_text}\n")

# ---------------------------------------------------------------------------
# CTest: `ctest --test-dir build` as an alternative to run_all.sh.
# Note that everything except the parser test needs an sm_80+ GPU.
# ---------------------------------------------------------------------------
enable_testing()
set(DATA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/data)

add_test(NAME parsers
         COMMAND $<TARGET_FILE:test_parsers>
                 ${DATA_DIR}/geometry/h2o.xyz ${DATA_DIR}/basis_set/def2-svp.gbs)
add_test(NAME one_electron_integrals
         COMMAND $<TARGET_FILE:one_electron_integrals>
                 ${DATA_DIR}/geometry/h2o.xyz ${DATA_DIR}/basis_set/def2-svp.gbs)

if(TARGET one_electron_integrals_oracle)
    add_test(NAME one_electron_integrals_vs_c
             COMMAND ${CMAKE_COMMAND}
                 -DFORTRAN_EXE=$<TARGET_FILE:one_electron_integrals>
                 -DC_EXE=$<TARGET_FILE:one_electron_integrals_oracle>
                 -DCOMPARE=${CMAKE_CURRENT_SOURCE_DIR}/compare.py
                 -DXYZ=${DATA_DIR}/geometry/h2o.xyz
                 -DGBS=${DATA_DIR}/basis_set/def2-svp.gbs
                 -DWORKDIR=${CMAKE_BINARY_DIR}
                 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunCompare.cmake)
endif()

message(STATUS "")
message(STATUS "  Build:  cmake --build ${CMAKE_BINARY_DIR} -j")
message(STATUS "  Run  :  ./run_all.sh ${CMAKE_BINARY_DIR}")
message(STATUS "  NOTE :  cuEST requires sm_80+; only the parser test runs on Volta.")
message(STATUS "")
