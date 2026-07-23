# cudafort — Fortran bindings to the CUDA APIs

Standard Fortran 2008 `iso_c_binding` interfaces to the **CUDA Runtime API** and
**CUDA Driver API**, generated directly from the CUDA toolkit headers.

The aim is the coverage of NVIDIA's `cudafor` module without the dependency on
`nvfortran`: everything here is plain, portable Fortran with no compiler
extensions, so it builds under gfortran / ifort / ifx / flang as well, and the
directory can be dropped into any project as-is.

| File | Role |
|------|------|
| `cuda_runtime.f90` | **Generated.** Module `cuda_runtime` — the Runtime API. |
| `cuda_driver.f90` | **Generated.** Module `cuda_driver` — the Driver API. |
| `cuda_helpers.f90` | Hand-written convenience layer (error strings, typed array copies, device reporting). |
| `generate_cuda_fortran.py` | Regenerates both modules from `$CUDA_HOME/include`. |
| `test_cuda.f90` | Self-test. Uses no cuEST, so it runs on **any** CUDA GPU. |
| `Makefile` | `make` / `make test` / `make regen` / `make clean`. |

## What is covered

Generated against **CUDA 12.9.0**:

| | Runtime | Driver |
|---|---|---|
| functions | 318 | 448 |
| enum constants | 659 | 833 |
| macro flag constants | 71 | 48 |
| derived types | 90 | 79 |

That is **766 entry points** and **1611 constants**. Every struct's layout is
verified against the C compiler's own `sizeof`/`offsetof` at generation time.

## Quick start

```sh
module load gcc/13.2.0 && module load cuda      # on Gadi
make CUDA_HOME=$CUDA_HOME
make test CUDA_HOME=$CUDA_HOME
```

```fortran
use, intrinsic :: iso_c_binding
use cuda_runtime
use cuda_helpers            ! optional

type(c_ptr)    :: d = c_null_ptr
integer(c_int) :: ist
real(c_double) :: h(1024), back(1024)

ist = cudaMalloc(d, 1024_c_size_t * 8_c_size_t)
call cuda_check(ist, "cudaMalloc")

ist = cuda_memcpy_to_device(d, h)      ! no C_LOC/C_SIZEOF at the call site
ist = cuda_memcpy_to_host(back, d)
ist = cuda_free(d)

call cuda_report_devices()
```

Link with `-lcudart` for the runtime module; the driver module needs
`-L$CUDA_HOME/lib64/stubs -lcuda`.

## Why this is generated rather than hand-written

Three traps make hand-maintained CUDA bindings unreliable. The generator
handles each explicitly and **fails loudly rather than emitting a guess**.

### 1. Versioned symbols

`cuda_runtime_api.h` contains

```c
#define cudaGetDeviceProperties cudaGetDeviceProperties_v2
```

The *unversioned* symbol also exists in `libcudart.so`, as a backward-compat
stub that takes the **old** `cudaDeviceProp` layout. Binding the obvious name
links cleanly and then silently misbehaves. The generator resolves these
aliases and binds the versioned symbol while keeping the friendly Fortran name:

```fortran
integer(c_int) function cudaGetDeviceProperties(prop, device) &
        bind(C, name="cudaGetDeviceProperties_v2")   ! header aliases ...
```

There are 15 such `_vN` symbols in CUDA 12.9.

### 2. Struct layout is measured, never assumed

`cudaDeviceProp` has ~100 fields, and `driver_types.h` contains structs with
embedded **C unions**, which Fortran `BIND(C)` cannot express. So the generator
emits a C probe reporting `sizeof`/`offsetof` for every type and field, compiles
and runs it, and then independently predicts the Fortran layout and compares.

*A type whose predicted layout disagrees is dropped, not emitted with a
warning* — a silently wrong struct layout corrupts memory at run time, which is
far worse than a missing declaration.

Unions and anonymous members become correctly-sized byte arrays:

- a **named** union is an opaque buffer tiled with the widest integer kind that
  divides its size, so it reproduces the union's alignment;
- an **anonymous** union (`cudaGraphNodeParams`) and a **computed-size** array
  (`cudaLaunchAttribute_st`'s `char pad[8 - sizeof(...)]`) cannot be measured by
  name, so they are sized from the gap between their named neighbours and
  absorb their own padding.

Current status: all 89 runtime structs match C exactly. One driver type,
`CUtensorMap_st`, is **deliberately omitted** — it requires 64-byte alignment
that `BIND(C)` cannot express. That costs 4 `cuTensorMapEncode*` functions.

### 3. Symbol resolution

Every emitted `bind(C, name=…)` is checked against `nm -D` on `libcudart.so` /
`libcuda.so`. Unresolved names are reported and dropped.

### Also handled

- **Preprocessing is done by the real `cpp`**, not by regex. This resolves
  `#if defined(__cplusplus)` (so `dim3` is a plain C struct, not one carrying
  C++ constructors), expands sizing macros (`CUDA_IPC_HANDLE_SIZE` → 64), and
  strips `__device_builtin__` / `__host__` / `CUDARTAPI` / `__dv()`.
- **Macro flags.** `cudaStreamNonBlocking`, `cudaEventDefault`,
  `cudaHostAllocDefault` and ~115 others are `#define`s, not enumerators. They
  are harvested with `cpp -dM` so `#if` branches resolve exactly as they would
  in a real compile.
- **Fortran is case-insensitive, C is not.** CUDA defines both the enum constant
  `cudaLibraryHostUniversalFunctionAndDataTable` and the struct tag
  `cudalibraryHostUniversalFunctionAndDataTable`. Enum constants keep their C
  spelling; a colliding *type* is renamed with a `_t` suffix.
- **63-character identifier limit.** Two driver enum constants exceed it and are
  abbreviated (`CU_DEVICE_ATTRIBUTE_` → `CU_DEV_ATTR_`), each with a comment
  recording the true C name. Only the integer value crosses the ABI, so the
  alias is exact.
- **`void**` direction.** It is an OUT parameter almost everywhere
  (`cudaMalloc`), but in the launch APIs (`args`, `extra`, `kernelParams`) it is
  an IN array of pointers. Declaring those `intent(out)` would make passing
  arguments undefined behaviour, so they are declared
  `type(c_ptr), dimension(*), intent(in)`.

## Type mapping

| C | Fortran |
|---|---|
| `cudaError_t` / `CUresult` return | `integer(c_int)` function result |
| opaque handle in (`cudaStream_t`, `cudaEvent_t`, …) | `type(c_ptr), value` |
| opaque handle out (`cudaStream_t*`) | `type(c_ptr), intent(out)` |
| `void*`, `const void*` | `type(c_ptr), value` |
| `void**` (out) / (launch args) | `type(c_ptr), intent(out)` / `dimension(*), intent(in)` |
| `const char*` | `character(kind=c_char), dimension(*), intent(in)` |
| function pointer typedef | `type(c_funptr), value` |
| enum by value / `enum*` out | `integer(c_int), value` / `intent(out)` |
| `struct X` by value / `X*` / `const X*` | `type(X), value` / `intent(inout)` / `intent(in)` |
| C union | `type(X)` wrapping a probe-sized byte array |
| scalars (`int`, `size_t`, `float`, `double`, …) | `integer(…)`, `real(…)`, `value` |

## Regenerating

```sh
make regen CUDA_HOME=/path/to/cuda      # or: python3 generate_cuda_fortran.py
```

Options: `--api runtime|driver|both`, `--cuda <root>`, `--cc <compiler>`,
`--no-probe` (skips layout validation — union-bearing types are then omitted
rather than guessed).

Struct layouts change between CUDA releases, so **regenerate rather than
hand-edit** when moving toolkits. The generated header records the CUDA version
it came from.

## Verified

- Generated from CUDA 12.9.0, driver 580.x.
- Compiles warning-free with `gfortran 13.2.0` under `-std=f2008 -Wall` and
  `-std=f2018 -Wall -pedantic`, and with `ifort 2021.8.0` under
  `-stand f08 -warn all`.
- `make test` passes all 37 checks on a Tesla V100 (sm_70), covering version
  query, device enumeration, malloc/memcpy/memset round trips, streams, events
  and timing, async copies, pinned host memory, error decoding, and
  `cudaDeviceProp` field readback.
- The driver module was separately confirmed to link and run
  (`cuInit` → `cuDeviceGetCount`).

`nvfortran` and `ifx` are expected to work — the code is standard Fortran 2008 —
but neither is installed on this machine, so that is untested.

## Scope

Not included: GL / EGL / VDPAU graphics interop (`cudaGL.h`, `cudaEGL.h`,
`cudaVDPAU.h`). They require external SDK headers and `#include` `cuda.h`, which
would drag the whole driver API into the runtime module. Graphics interop
belongs in its own optional module if it is ever needed.

The math libraries (cuBLAS, cuSOLVER, cuFFT, cuRAND) follow the same
handle+enum+status shape and the generator is structured to extend to them —
add an entry to the `APIS` table — but they are not currently generated.

## Attribution

These bindings are mechanically derived from the CUDA toolkit headers, which
NVIDIA ships under the CUDA Software Licence Agreement. Before publishing or
redistributing this directory, confirm that redistributing header-derived
interface declarations and enum values is acceptable for your use.
