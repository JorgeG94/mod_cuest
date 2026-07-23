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
make regen            # or: python3 generate_cuest_fortran.py ../include
make
```

The generator parses the headers for enums, opaque typedefs, and prototypes and
applies the mapping table above. If cuEST introduces a C type the mapper doesn't
recognise, it stops with `UNMAPPED ARG: …` pointing at the new case to add in
`map_arg()` — nothing is emitted silently.

## Gotchas learned the hard way

- **Match the package to your driver.** The `cuda13` build JIT-compiles kernels
  at `cuestCreate` and needs a CUDA-13-capable driver (r580+); on a box whose
  `nvidia-smi` shows "CUDA Version: 12.x" it throws `CUEST_STATUS_EXCEPTION`.
  Use the `…_cuda12-archive` build there instead — the Fortran module is
  identical (just `make regen` against that package's headers).
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
- The bindings are pure interface declarations — they add no overhead and make
  no assumptions about host vs device memory beyond the mapping above.
- JIT-compiled kernels require CUDA 13.x (this is the `_cuda13` package).
