# Plan: native Fortran port of the cuEST sample suite

Working document. Status markers: `TODO` / `WIP` / `DONE`. Update as we go.

**Goal.** A Fortran counterpart to each of the 29 C samples in the cuEST package's
`CUDALibrarySamples/cuEST/c_examples/examples/`, numerically validated against the C
build. See `CLAUDE.md` for environment, build commands, and the cuEST API idioms.

**Paths.** This repo holds the Fortran side only; `include/`, `lib/` and
`CUDALibrarySamples/` come from the unpacked cuEST binary archive, and the repo
contents are meant to sit in that package's `fortran/` directory. Where this
document says "the samples", it means the package's copy.

**Why the prerequisites came first.** The C samples rest on ~2k lines of shared helpers
in `c_examples/common/`, and there was no Fortran equivalent. The original
`example_overlap.f90` dodged this by hardcoding H2/STO-3G and inlining
`chk`/`make_ws`/`free_ws` into its `contains` block; porting samples on that basis
would have meant copy-pasting the scaffolding 29 times. That shared layer now exists
in `fortran_examples/common/`, and `example_overlap.f90` has been removed as
superseded (it is in git history).

---

## Step 1 — CUDA runtime + driver bindings module `DONE`

Delivered in `cudafort/`. See `cudafort/README.md` for full detail.

Result, generated from CUDA 12.9.0:

| | Runtime | Driver |
|---|---|---|
| functions | 318 | 448 |
| enum constants | 659 | 833 |
| macro flag constants | 71 | 48 |
| derived types | 90 | 79 |

766 entry points, 1611 constants, ~10k generated lines from a 1.4k-line
generator. All 89 runtime struct layouts verified against the C compiler's own
`sizeof`/`offsetof`. `make test` passes 39 checks on the V100 login node.
Compiles clean under gfortran `-std=f2008`/`-std=f2018 -pedantic` and ifort
`-stand f08`.

Deliberately omitted: `CUtensorMap_st` (needs 64-byte alignment that `BIND(C)`
cannot express; costs 4 `cuTensorMapEncode*` functions) and GL/EGL/VDPAU
graphics interop (needs external SDK headers, and pulls the driver API into the
runtime module).

Steps 2–4 are built on `cuda_runtime` + `cuda_helpers`. The ad-hoc `cuda_rt`
module that `example_overlap.f90` used to inline is gone with that file.

<details><summary>Original specification</summary>

A large, standalone, compiler-agnostic Fortran binding to the CUDA APIs: the
functionality of NVIDIA's `cudafor`, but pure `iso_c_binding` so it builds under
gfortran / ifx / flang as well as nvfortran, and can be dropped into any project.

**Scope.** CUDA Runtime API (375 functions) and CUDA Driver API (611 functions), plus
their enums and structs. Delivered as separate modules so a project can take just one.
The math libraries (cuBLAS/cuSOLVER/cuFFT/cuRAND) follow the same handle+enum+status
shape and the generator should extend to them later, but they are **not** in scope here.

**Generated, not hand-written** — same philosophy as `generate_cuest_fortran.py`.
Parse `$CUDA_HOME/include/{cuda_runtime_api.h, driver_types.h, vector_types.h,
library_types.h, texture_types.h, surface_types.h}` and `cuda.h`.

Three problems the generator must solve, each with a decided approach:

1. **Versioned symbol aliases.** `cuda_runtime_api.h` contains
   `#define cudaGetDeviceProperties cudaGetDeviceProperties_v2`, and there are 15 `_vN`
   symbols in `libcudart.so`. The unversioned symbol *also* exists as a
   backward-compatibility stub taking the **old** struct layout. Binding the plain name
   is therefore a silent ABI mismatch, not a link error. The generator must resolve
   these `#define`s and emit `bind(C, name="cudaGetDeviceProperties_v2")`.

2. **Struct layout must be verified, not assumed.** `cudaDeviceProp` has ~100 fields;
   `driver_types.h` contains 57 structs, 10+ of which embed **unions**, which Fortran
   `bind(C)` cannot express. Approach: the generator also emits a small **C probe
   program** printing `sizeof()` and `offsetof()` for every type and field it generated.
   Compile and run the probe, diff against the Fortran layout. Unions become
   `integer(c_int8_t) :: raw(N)` with N taken from the probe, plus accessor helpers where
   worth it. This turns "hope the layout matches" into a build-time check.

3. **Symbol resolution.** Cross-check every emitted `bind(C, name=…)` against
   `nm -D libcudart.so` / `libcuda.so`. Anything that doesn't resolve is reported, not
   emitted silently. Same fail-loud principle as the cuEST generator's `UNMAPPED ARG`.

**Deliverables**
- `generate_cuda_fortran.py`
- `cuda_runtime.f90` — module `cuda_runtime`: enum parameters, `bind(C)` derived types,
  interfaces for all runtime functions
- `cuda_driver.f90` — module `cuda_driver`, likewise
- `cuda_helpers.f90` — hand-written thin layer: `cuda_check`, `cudaGetErrorString`
  returning a Fortran `character(:)`, generic `cudaMemcpy` overloads taking Fortran
  arrays instead of `c_loc`
- `layout_probe.c` (generated) + a test program exercising device query, malloc/memcpy/
  free, streams, events, and graphs
- `README.md` documenting the type mapping and regeneration

**Testable on the V100 login node** — this module has nothing to do with cuEST, so the
sm_70 restriction does not apply. Full test coverage without touching the queue.

**Lives in its own top-level directory**, not under `fortran/`, since the point is that
it is droppable into unrelated projects.

</details>

---

## Step 2 — Device memory helper `TODO`

A `device_array` derived type: `alloc(n)` / `from_host(a)` / `to_host(a)` / `free()`,
for `real(c_double)` at minimum. Every sample repeats
`cudaMalloc(d, int(n*n,c_size_t)*8_c_size_t)` + `cudaMemcpy` + `cudaFree`. Biggest
line-count win of any item here. Depends on Step 1.

## Step 3 — Workspace helper `DONE`

`ws_alloc(ws, desc)` / `ws_free(ws)` in `fortran_examples/common/cuest_sample_utils.f90`,
replacing the `make_ws` / `free_ws` pair that used to be inlined per program. Saves ~15 lines per object
per sample and puts the "persistent workspace must outlive the object it created" rule
in one place instead of 29. Mirrors `common/helper_workspaces.h`.

## Step 4 — Status checking `PARTIAL`

`cuest_check(status, what)` and `cuda_check(code, what)` in a module rather than
re-declared per program. Mirrors `common/helper_status.h`.

Also: make `generate_cuest_fortran.py` emit `cuest_status_name` from the
`CUEST_STATUS_*` enum block. It is currently a hand-maintained `select case` in
`cuest_helpers.f90` that will silently drift on the next cuEST release.

## Step 5 — Parsers and basis-set construction `PARTIAL`

Fortran equivalents of the `common/` helpers. These unlock sample groups 1–4:

- `xyz_parser.f90` ← `helper_xyz_parser.h` — **DONE** (`fortran_examples/common/`)
- `gbs_parser.f90` ← `helper_gbs_parser.h` — **DONE**
- shell normalization ← `helper_shell_normalization.h` — **DONE** (in `ao_shells.f90`)
- `ao_shells.f90` ← `helper_ao_shells.h` (`formAOShells`) — **DONE**

Verified: `fortran_examples/test_parsers` cross-checks the parsed exponents and
normalized coefficients against NVIDIA's own C helpers for def2-SVP O and H --
all 17 primitives agree to zero relative difference. It creates no cuEST handle,
so it runs on Volta and needs no queue submission.

Deferred until their own sample groups: `ecp_parser` (group 5), `grid` (groups 1, 4),
`pcm` (group 6).

## Step 6 — Build and validation harness `TODO`

- Makefile with a `common/` archive and a pattern rule per example, replacing the
  current single-example Makefile.
- A `gpuhopper` PBS script that runs the C and Fortran binaries **in the same job** so
  outputs can be diffed directly. The C suite already builds cleanly here (all 29
  targets) and is the numerical oracle.
- A compare script asserting agreement to a tolerance.
- Argv handling helper (`get_command_argument`) — most samples take `<xyz> <gbs>`.

---

## Porting order, once Steps 1–6 land

1. `0_context` (4) — no parsers needed, exercises Step 1 hardest (streams, multi-GPU)
2. `2_one_electron_integrals` (4) — **1 of 4 done**: `one_electron_integrals`
   (S, T, V) is ported and **verified on Hopper against the C reference: zero
   relative difference on every compared quantity**
3. `1_basic_data_structures` (7)
4. `3_density_fitting` (4)
5. `4_exchange_correlation` (6) — leave `advanced_local_xc_{potential,gradient}` for
   last; at ~2.4k lines each they implement user B86/LTA functionals on the host, so
   they are an algorithm port, not an API translation
6. `5_effective_core_potentials` (2) — needs `ecp_parser`
7. `6_pcm` (2) — needs `pcm` helper

No sample contains a `.cu` file; all GPU work is inside cuEST. The only CUDA a port
needs is runtime API calls, which is exactly what Step 1 provides.

---

## Open decisions

- **File-for-file or consolidated?** 29 standalone programs mirroring the C tree and
  argv contract (easiest to diff against the oracle, more boilerplate), or fewer driver
  programs with subcommands? Recommendation: file-for-file, for diffability.
- **Licensing.** The CUDA module is derived from NVIDIA headers shipped under the CUDA
  SLA. If it is to be published or dropped into third-party projects, that needs a
  deliberate answer. Interfaces and enum values are arguably facts, but this is a call
  to make explicitly, not by default.

## Housekeeping

- **This is not a git repository.** Recommend `git init` before generating tens of
  thousands of lines. Exclude `lib/*.so*` (63 MB), `lib/*.a` (54 MB), `fortran/*.nsys-rep`,
  `fortran/*.sqlite`, build outputs.
- Delete the `._*` AppleDouble files left over from a macOS transfer.
- Pin the CUDA version the bindings were generated against (12.9.0 here) in a header
  comment; struct layouts change between CUDA releases, which is what the layout probe
  in Step 1 is there to catch.
