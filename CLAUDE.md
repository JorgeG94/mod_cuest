# mod_cuest — working notes

Native Fortran 2008 bindings to NVIDIA **cuEST** (CUDA Electronic Structure), plus
`cudafort/` (standalone CUDA API bindings), plus an in-progress effort to reproduce
NVIDIA's C sample suite in idiomatic Fortran. See `PLAN.md` for the roadmap.

## Layout, and how this repo relates to the cuEST package

This repo holds only the Fortran side. cuEST itself ships as a binary archive
(`libcuest-linux-x86_64-<ver>_cuda12-archive/`) providing `include/`, `lib/` and
`CUDALibrarySamples/`. **The repo contents are meant to sit in that package's
`fortran/` directory** — the Makefile's `CUEST_ROOT ?= ..` assumes exactly that, so
`../include` and `../lib` resolve. Working anywhere else means passing
`CUEST_ROOT=/path/to/package` explicitly.

| Path | Role |
|---|---|
| `cuest.f90` | **GENERATED — do not hand-edit.** Module `cuest`: 289 enum `parameter`s, the 2 workspace `bind(C)` types, interfaces for all 129 cuEST functions. |
| `generate_cuest_fortran.py` | Regenerates `cuest.f90` from the package's `include/`. |
| `cuest_helpers.f90` | Hand-written. Typed wrappers over the generic `void*+size_t` parameter/query API, plus `cuest_status_name`. |
| `example_overlap.f90` | Worked example: H2 / STO-3G overlap matrix, hardcoded basis. Also carries an inline `cuda_rt` module — **superseded by `cudafort/`**; delete it once Step 2 of `PLAN.md` lands. |
| `cudafort/` | Standalone, generated Fortran bindings to the CUDA Runtime + Driver APIs. Self-contained and droppable into unrelated projects. Has its own README. |
| `PLAN.md` | The porting roadmap. Working document — keep its status markers current. |

## Environment (NCI Gadi)

Always load these first — nothing builds without them:

```sh
module load gcc/13.2.0
module load cuda            # -> CUDA 12.9 at $CUDA_HOME
```

```sh
make                                        # cuest.mod, cuest_helpers.mod
make example CUDA_LIBDIR=$CUDA_HOME/lib64   # -> ./overlap_demo
cd cudafort && make test CUDA_HOME=$CUDA_HOME
```

### GPU architecture constraint — read this before debugging a runtime failure

`libcuest.so` ships cubins for **sm_80, 86, 89, 90, 100, 120 only**. Volta (sm_70) is
not supported.

- The Gadi **login node has a V100**, so `./overlap_demo` there fails at `cuestCreate`
  with status `11` = `CUEST_STATUS_UNSUPPORTED_ARCHITECTURE`. This is expected, not a
  bug in the bindings. Compiling and linking work fine on the login node.
- Run on `gpuhopper` (H100, sm_90) or `dgxa100` (A100, sm_80). `gpuvolta` will not work.
- Driver here is 580.x (advertises CUDA 13), so the `_cuda12` package is fine.

Practical consequence: **everything is developed and compiled interactively, but
cuEST work is validated in a batch job.** Assume any "did it actually run?" question
about cuEST needs a queue submission, and say so rather than reporting a login-node
failure as a defect.

`cudafort/` has no such constraint — it does not touch cuEST, so its self-test runs
on the V100 login node.

### Reference C build (the oracle)

The upstream C samples build cleanly and are the ground truth when porting:

```sh
cmake -S <pkg>/CUDALibrarySamples/cuEST/c_examples -B <build> \
      -DCUEST_INCLUDE_DIR=<pkg>/include -DCUEST_LIB_DIR=<pkg>/lib \
      -DCMAKE_CUDA_ARCHITECTURES="80;90"
cmake --build <build> -j16
```

Sample input data lives in `<pkg>/CUDALibrarySamples/cuEST/data/` (`geometry/*.xyz`,
`basis_set/*.gbs`). Most samples take `<xyz_file> <gbs_file>` as argv.

## How the bindings are produced

Both `cuest.f90` and everything in `cudafort/` are mechanical output. If the headers
change, do **not** patch the `.f90`:

```sh
make regen && make                 # cuEST
cd cudafort && make regen          # CUDA
```

Both generators **fail loudly** rather than emitting a guess — `UNMAPPED ARG` for
cuEST, `UNMAPPED`/dropped-and-reported for CUDA.

cuEST type mapping:

| C | Fortran |
|---|---|
| `cuestStatus_t` return | `integer(c_int)` function result |
| opaque handle in | `type(c_ptr), value` |
| opaque handle out (`T*` ≡ `void**`) | `type(c_ptr), intent(out)` |
| array of input handles (`const T*`) | `type(c_ptr), dimension(*), intent(in)` |
| `double*` / `const double*` / `void*` | `type(c_ptr), value` |
| `const uint64_t*` / `const uint32_t*` | `integer(c_int64_t/32_t), dimension(*), intent(in)` |
| `uint32_t*`, `<enum>*` (scalar out) | `integer(…), intent(out)` |
| scalars (`double`, `uintNN_t`, `int`, enums) | `real(c_double)` / `integer(…)`, `value` |
| `cuestWorkspace(Descriptor)_t*` | the `bind(C)` derived types |

Verified against v0.2.0 headers: every prototype returns `cuestStatus_t`, and there
are no non-`const uint64_t*`, no `double**`, and no `char*` arguments — so the table
is complete with no latent mis-mappings. Re-check if the version bumps.

Six enum constants exceed Fortran's 63-char identifier limit; the generator shortens
`PARAMETERS`→`PARAM` and leaves a `! C name …` comment. Only the integer value
crosses the ABI, so the alias is exact.

## cuEST API idioms that bite

These are the mistakes that cost time; they are non-obvious from the headers.

1. **Every parameters object must be created — never pass `c_null_ptr`.** Even object
   types documented as having no configurable parameters (AO shell / basis / pair list /
   plans) still need a live handle from `cuestParametersCreate(<TYPE>_PARAMETERS, p)`,
   destroyed afterwards. Passing NULL returns `CUEST_STATUS_NULL_POINTER`.

2. **Host vs device pointers are not distinguishable from the signature.** Both map to
   `type(c_ptr), value`. Getting it wrong is a segfault, not a status code.
   - **HOST**: shell exponents/coefficients, pair-list atom coordinates (`xyzCPU`),
     grid definitions, `numShellsPerAtom`. Pass `c_loc(host_array)`; the array needs
     the `target` attribute.
   - **DEVICE**: all integral/matrix outputs and density inputs.

3. **Workspaces follow query → allocate → call.** Call the `…WorkspaceQuery` variant
   with the same arguments to fill two `cuestWorkspaceDescriptor_t` (persistent and
   temporary), allocate host and device scratch of those sizes into a
   `cuestWorkspace_t`, then make the real call. The temporary workspace is freeable
   immediately after; the **persistent one must outlive the object it created**.

4. **`cuestWorkspace_t`'s buffer fields are `uintptr_t`, not pointers.** Store a
   `type(c_ptr)` with `transfer(dptr, ws%deviceBuffer)` and recover it with
   `transfer(ws%deviceBuffer, c_null_ptr)`.

5. **A buffer that "may be NULL"** (e.g. `outSMatrix` during a workspace query) is just
   `c_null_ptr`.

## Conventions

- Generated modules are `public` in bulk; hand-written helper modules are `private`
  with explicit `public ::` lists. Keep that.
- Every cuEST/CUDA call's status is checked. Don't silently drop a status code.
- Compile warning-free under `gfortran -std=f2008 -Wall`. `cudafort` is additionally
  verified under `-std=f2018 -pedantic` and `ifort -stand f08`.
- `.gitignore` note: a bare `Makefile` rule (intended for CMake output) used to
  silently exclude this project's hand-written Makefiles from the repo. It is now
  scoped to `build*/Makefile`. Don't reintroduce the bare rule.
- `._*` files are macOS AppleDouble junk from a transfer; safe to delete, never edit.
