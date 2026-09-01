# cuEST — Fortran interface

Fortran 2008 `iso_c_binding` bindings for NVIDIA **cuEST** (CUDA Electronic
Structure), generated from the cuEST C headers.

`cuest.f90` is checked in, so building the bindings needs only a Fortran compiler --
no cuEST package. The package is needed to *link* (`lib/`), to run the examples, and
to regenerate (`include/`); point at it with `CUEST_ROOT`. This repository can live
anywhere; it is normally a sibling of the unpacked package, not inside it.

The binding exposes the **entire** public API: **129 functions**, **289 enum
constants** (83 enums), the **67 opaque handle types**, and the **2 workspace
structs** — as of cuEST v0.2.0.

| File | Purpose |
|------|---------|
| `cuest.f90` | The `cuest` module: enum PARAMETERs, the two workspace derived types, and `INTERFACE` blocks for every cuEST function. **Generated — do not edit.** |
| `cuest_helpers.f90` | Optional `cuest_helpers` module: typed convenience wrappers over the generic `void*+size` get/set/query API. |
| `generate_cuest_fortran.py` | Regenerates `cuest.f90` from the headers. |
| `Makefile` | `make` / `make regen` / `make clean` — builds the bindings only. |
| `cudafort/` | Standalone Fortran bindings to the CUDA Runtime + Driver APIs. Own README. |
| `fortran_examples/` | Worked examples: ports of NVIDIA's cuEST C samples, with a shared helper layer, bundled input data and a C reference oracle. Own README. |

## Quick start

```fortran
use, intrinsic :: iso_c_binding
use cuest
use cuest_helpers          ! optional typed get/set wrappers

type(c_ptr)    :: handle = c_null_ptr, hpar = c_null_ptr
integer(c_int) :: ist

ist = cuestParametersCreate(CUEST_HANDLE_PARAMETERS, hpar)
ist = cuestCreate(hpar, handle)                 ! handle is returned (C void**)
ist = cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, hpar)
ist = cuestSetMathMode(handle, CUEST_NATIVE_FP64_MATH_MODE)
! ... use the API ...
ist = cuestDestroy(handle)
if (ist /= CUEST_STATUS_SUCCESS) error stop
```

## Build

```sh
make                 # -> cuest.mod, cuest_helpers.mod, cuest.o, cuest_helpers.o
```

For runnable examples, see `fortran_examples/` (CMake, one variable):

```sh
cmake -S fortran_examples -B fortran_examples/build -DCUEST_ROOT=<cuest package>
cmake --build fortran_examples/build -j
./fortran_examples/run_all.sh fortran_examples/build
```

Link your program against the shared (or static) cuEST library and the CUDA
runtime:

```sh
gfortran myapp.f90 cuest.o cuest_helpers.o -o myapp \
    -L../lib -lcuest -lcudart -Wl,-rpath,../lib
```

Tested to compile warning-free with `gfortran -std=f2008 -Wall` (GCC 15) and
`-std=f2018 -pedantic`. It is standard Fortran 2008 and also builds with
`nvfortran` / `ifx` (`make FC=nvfortran`).

## Adding this to an existing Fortran project

The binding is two source files with no dependencies beyond `iso_c_binding`, so
"integrating" it means compiling them alongside your own code. There is nothing
to install and no configuration step.

### 1. Take the files you need

| file | when |
|---|---|
| `cuest.f90` | always — the `cuest` module |
| `cuest_helpers.f90` | recommended — typed `query`/`configure` wrappers and `cuest_status_name` |
| `cudafort/cuda_runtime.F90` | if you need `cudaMalloc`/`cudaMemcpy` etc. and are not already using `cudafor` |
| `cudafort/cuda_helpers.f90` | optional — `cuda_check`, typed array copies |

You will need *some* way to allocate device memory, because cuEST reads and
writes GPU buffers. If you build with `nvfortran` you already have `cudafor`;
otherwise take `cudafort/`, which is compiler-agnostic. See its own README.

Copy them in (e.g. under `third_party/cuest_fortran/`), or add this repository as
a git submodule. Do not edit `cuest.f90` — regenerate it instead (see below).

### 2. Compile them before your code

Fortran module files must exist before anything that `use`s them, so compile
`cuest.f90` first, then `cuest_helpers.f90`, then your sources.

**Plain make:**

```make
CUEST_ROOT ?= /path/to/libcuest-linux-x86_64-<ver>_cuda12-archive
CUDA_LIBDIR ?= $(CUDA_HOME)/lib64

CUEST_LIBS := -L$(CUEST_ROOT)/lib -lcuest -L$(CUDA_LIBDIR) -lcudart \
              -Wl,-rpath,$(CUEST_ROOT)/lib -Wl,-rpath,$(CUDA_LIBDIR)

myapp: main.f90 cuest.o cuest_helpers.o
	$(FC) $^ -o $@ $(CUEST_LIBS)

cuest.o:         third_party/cuest_fortran/cuest.f90         ; $(FC) -c $<
cuest_helpers.o: third_party/cuest_fortran/cuest_helpers.f90 ; $(FC) -c $<
```

**CMake** — CMake derives Fortran compile order from `MODULE`/`USE`, so the
sources can simply be listed:

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES Fortran)
find_package(CUDAToolkit REQUIRED)

add_library(cuest_fortran STATIC
    third_party/cuest_fortran/cuest.f90
    third_party/cuest_fortran/cuest_helpers.f90)
target_link_libraries(cuest_fortran
    PUBLIC ${CUEST_ROOT}/lib/libcuest.so CUDA::cudart)
target_include_directories(cuest_fortran
    PUBLIC ${CMAKE_Fortran_MODULE_DIRECTORY})

add_executable(myapp main.f90)
target_link_libraries(myapp PRIVATE cuest_fortran)
```

Configure with `-DCUEST_ROOT=/path/to/libcuest-...-archive`. Linking the `.so` by
full path makes CMake add the rpath for you.

Only the cuEST **library** is needed to build against. Headers are not: the
binding is pre-generated and checked in.

### 3. Check the link before writing real code

This compiles and runs on any machine with the library present — it deliberately
creates no cuEST handle, so it does not need a supported GPU:

```fortran
program check_cuest
    use, intrinsic :: iso_c_binding
    use cuest
    use cuest_helpers, only: cuest_status_name
    implicit none
    type(c_ptr)    :: params = c_null_ptr
    integer(c_int) :: ist

    write(*,'(A,I0,".",I0,".",I0)') "built against cuEST headers v", &
        CUEST_VER_MAJOR, CUEST_VER_MINOR, CUEST_VER_PATCH

    ist = cuestParametersCreate(CUEST_HANDLE_PARAMETERS, params)
    call check(ist, "cuestParametersCreate")
    ist = cuestParametersDestroy(CUEST_HANDLE_PARAMETERS, params)
    call check(ist, "cuestParametersDestroy")

    write(*,'(A)') "cuEST is linked and callable."

contains

    ! Note: ERROR STOP takes a *constant* stop code in Fortran 2008; passing a
    ! computed string is a 2018 extension. Print, then stop with a literal.
    subroutine check(status, what)
        integer(c_int), intent(in) :: status
        character(*),   intent(in) :: what
        write(*,'(A,A,A)') what, " -> ", cuest_status_name(status)
        if (status /= CUEST_STATUS_SUCCESS) error stop 1
    end subroutine check

end program check_cuest
```

If that runs, your build is wired correctly and any later failure is an API
usage problem rather than an integration one.

### 4. Then read the gotchas

The API has three conventions that are not visible in the Fortran signatures and
will cost you an afternoon each. They are documented below under *Gotchas
learned the hard way* and *Workspaces*, but in short: every parameters object
must be created rather than left `c_null_ptr`; `type(c_ptr)` arguments are
sometimes host and sometimes device addresses; and object creation follows
query → allocate → create.

`fortran_examples/` contains 29 worked programs covering the whole API, each
verified against NVIDIA's own C sample. `fortran_examples/common/` is a
ready-made scaffolding layer (status checking, workspace allocation, device
buffers) that is worth reading before writing your own.

> **Runtime requirement.** cuEST ships GPU code for **sm_80 and newer** only.
> On anything older — including Volta/V100 — `cuestCreate` returns
> `CUEST_STATUS_UNSUPPORTED_ARCHITECTURE` (status 11). Everything still compiles
> and links there; it just cannot run.

> **Platform note.** The bundled `../lib/libcuest.so` is Linux/x86_64 and cuEST
> runs on NVIDIA GPUs, so the *final link/run* must happen on that target. The
> Fortran sources themselves compile anywhere (the `.mod` is host-independent).

## Type-mapping reference

| C (cuEST) | Fortran |
|-----------|---------|
| `cuestStatus_t` (every return) | `integer(c_int)` function result |
| opaque handle in, by value (`cuestHandle_t`, `const cuestOEIntPlan_t`, …) | `type(c_ptr), value` |
| opaque handle out (`cuestHandle_t*`, `void**`) | `type(c_ptr), intent(out)` |
| array of input handles (`const cuestAOShell_t*`) | `type(c_ptr), dimension(*), intent(in)` |
| data buffer (`double*`, `const double*`) — **GPU device pointer** | `type(c_ptr), value` |
| generic buffer (`void*`, `const void*`) | `type(c_ptr), value` |
| host metadata array (`const uint64_t*`, `const uint32_t*`) | `integer(c_int64_t/…), dimension(*), intent(in)` |
| scalar out (`uint32_t*` version, `cuestMathMode_t*`) | `integer(…), intent(out)` |
| scalars by value (`double`, `uint64_t`, `int`, any enum) | `real(c_double)` / `integer(…)` `, value` |
| `cuestWorkspace_t*`, `cuestWorkspaceDescriptor_t*` | `type(cuestWorkspace_t)` / `type(cuestWorkspaceDescriptor_t)` |

### Why `type(c_ptr)` for the big buffers?

In cuEST, matrices/coordinates/etc. (`double*`) are **device** pointers, so they
are exposed as `type(c_ptr), value`. Pass a device address (e.g. from
`cudaMalloc`), or `C_LOC(host_array)` for host data. This matches NVIDIA's own
cuBLAS/cuSOLVER v2 Fortran convention. A buffer that "may be NULL" (e.g.
`outSMatrix` during a workspace query) is just `c_null_ptr`.

### The generic query/configure API

Parameter objects and object attributes go through `void* + size_t`. Use the
`cuest_helpers` wrappers instead of hand-rolling `C_LOC`/`C_SIZEOF`:

```fortran
integer(c_int64_t) :: nao
ist = cuest_query_i64(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_AO, nao)

ist = cuest_param_set_i64(CUEST_HANDLE_PARAMETERS, hpar, &
        CUEST_HANDLE_PARAMETERS_MAX_GAUSS_HERMITE, 20_c_int64_t)
```

Wrappers exist for `i64`, `i32`, `f64` (`cuest_param_set/get_*`, `cuest_query_*`).
For `char*` attributes (e.g. `CUEST_XCINTPLAN_ENGINE_DESCRIPTION`) call
`cuestQuery` directly with a `type(c_ptr)` target and free it with C `free()`.

### Workspaces (`cuestWorkspace_t`)

Its `hostBuffer`/`deviceBuffer` fields are `uintptr_t` (raw addresses), so store
a pointer with `transfer`:

```fortran
type(cuestWorkspace_t) :: ws
type(c_ptr) :: dptr
ist = cudaMalloc(dptr, desc%deviceBufferSizeInBytes)
ws%deviceBuffer            = transfer(dptr, ws%deviceBuffer)
ws%deviceBufferSizeInBytes = desc%deviceBufferSizeInBytes
```

The usual pattern is **query → allocate → create/compute**: call the
`…WorkspaceQuery` variant to fill a `cuestWorkspaceDescriptor_t`, allocate host
and device scratch of those sizes, populate a `cuestWorkspace_t`, then call the
real function. See `fortran_examples/common/cuest_sample_utils.f90`.

## Regenerating after a cuEST update

The binding is produced mechanically, so a new cuEST release is a one-liner:

```sh
make regen CUEST_ROOT=/path/to/libcuest-...-archive
make
```

The generator parses the headers for enums, opaque typedefs, and prototypes and
applies the mapping table above. If cuEST introduces a C type the mapper doesn't
recognise, it stops with `UNMAPPED ARG: …` pointing at the new case to add in
`map_arg()` — nothing is emitted silently.

## Gotchas

- **Every `parameters` object must be created — never pass `c_null_ptr`.** Even
  types with "no configurable parameters" (AO shell/basis/pair-list/plan) still
  require a live handle from `cuestParametersCreate(<TYPE>_PARAMETERS, p)`,
  destroyed afterwards with `cuestParametersDestroy`. Passing NULL returns
  `CUEST_STATUS_NULL_POINTER`.
- **Host vs device pointers.** Shell exponents/coefficients and pair-list
  coordinates (`xyzCPU`) are HOST arrays (pass `C_LOC(...)`); integral output
  matrices are DEVICE buffers (`cudaMalloc`, then `cudaMemcpy` back). See
  `fortran_examples/`, whose one-electron integral port computes S, T and V
  end-to-end and matches NVIDIA's C reference exactly.

## Notes / caveats

- Six enum constants exceed Fortran's 63-character identifier limit; the
  generator shortens `PARAMETERS`→`PARAM` for those (only the integer *value*
  is passed to C, so the alias is exact). Each is flagged with a `! C name …`
  comment in `cuest.f90`.
