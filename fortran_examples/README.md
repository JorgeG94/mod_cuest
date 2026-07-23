# Fortran ports of the cuEST C samples

Native Fortran counterparts to the C samples in NVIDIA's
`CUDALibrarySamples/cuEST/c_examples/examples/`. See `../PLAN.md` for the roadmap
and which samples are done.

## Layout

```
common/     shared helpers, ports of c_examples/common/
data/       bundled geometry and basis sets (see licensing below)
oracle/     C reference, instrumented to print comparable numbers
<group>/    the ported samples, mirroring the C directory names
```

| `common/` module | Ports |
|---|---|
| `cuest_sample_utils.f90` | `helper_status.h`, `helper_workspaces.h`, plus device buffers and reporting |
| `xyz_parser.f90` | `helper_xyz_parser.h` |
| `gbs_parser.f90` | `helper_gbs_parser.h` |
| `ao_shells.f90` | `helper_ao_shells.h`, `helper_shell_normalization.h` |

## Build and run

Same shape as NVIDIA's `c_examples` build, but one variable does it all:

```sh
module load gcc/13.2.0 && module load cuda        # on Gadi
PKG=/path/to/libcuest-linux-x86_64-<ver>_cuda12-archive

cmake -S . -B build -DCUEST_ROOT=$PKG
cmake --build build -j
./run_all.sh build
```

`CUEST_ROOT` is the only required option. From it CMake derives:

| derived | used for |
|---|---|
| `$CUEST_ROOT/lib` | linking `libcuest.so` — the only hard requirement |
| `$CUEST_ROOT/include` | the C reference oracle (**not** the Fortran examples: the bindings are pre-generated, so no headers are needed) |
| `$CUEST_ROOT/CUDALibrarySamples/cuEST/c_examples/common` | the oracle's helper headers |

Any of `CUEST_LIB_DIR`, `CUEST_INCLUDE_DIR`, `CUEST_SAMPLES_COMMON_DIR` can be
set explicitly to override a derived value — NVIDIA's own spellings, so their
command lines transfer unchanged. If the samples checkout is missing, the
Fortran examples still build; only the numeric comparison is skipped.

Executables all land in `build/bin/`, and `ctest --test-dir build` works as an
alternative to `run_all.sh`.

Input data is bundled in `data/`, so nothing outside the package is needed at
run time.

### Adding an example

Add one line to the group's `CMakeLists.txt`:

```cmake
add_fortran_example(my_example my_example.f90 ARGS @XYZ@ @GBS@)
```

CMake records it in `build/examples.manifest`, which `run_all.sh` reads — so
the run script never needs editing. The `@TOKEN@` placeholders expand to the
bundled data files.

**cuEST needs sm_80 or newer.** Everything builds anywhere, but the samples only
*run* on A100/H100 (Gadi: `dgxa100` or `gpuhopper`, never `gpuvolta`). The one
exception is the `test_parsers` target, which creates no cuEST handle and so
runs anywhere — useful for checking the parsers without burning queue time.
`run_all.sh` detects the compute capability up front and says so plainly rather
than letting every example die with an opaque
`CUEST_STATUS_UNSUPPORTED_ARCHITECTURE`.

## Validating a port

The upstream C samples compute their integrals and exit **without printing
them**, so there is no reference output to diff against. `oracle/` therefore
holds a copy of the C sample with a `report_matrix()` added and nothing else
changed — the setup path is identical to upstream, which is what makes it a
reference rather than a reimplementation.

`run_all.sh` (and the `one_electron_integrals_vs_c` CTest case) runs both
binaries on the same input and calls `compare.py`,
which parses the numbers out of each output (rather than diffing text, so
formatting and `D`- vs `E`-exponents do not matter) and compares trace,
Frobenius norm, `max |A-A^T|` and every element of the leading 5x5 block at a
1e-10 relative tolerance.

Independent checks worth knowing, for h2o + def2-SVP: `nao` must be 24, the
overlap trace must be exactly 24 (unit diagonal on a normalized basis), and all
three matrices must be symmetric to round-off.

The parsers were separately verified against NVIDIA's own
`helper_gbs_parser.h` + `helper_shell_normalization.h`, compiled as an oracle:
all 17 primitives across O and H agree to zero relative difference.

## Licensing of the bundled data

`data/` contains verbatim copies of the geometry and basis set files from
`CUDALibrarySamples/cuEST/data/`, bundled so the examples are self-contained.

- The samples repository is **Apache-2.0** (NVIDIA); a copy of the licence is at
  `../LICENSE-Apache-2.0`.
- The `.gbs` basis sets come from the **Basis Set Exchange** and are
  **BSD-3-Clause** (MolSSI). Their `!` comment headers carry the upstream
  attribution and are left intact.
- `oracle/one_electron_integrals_oracle.c` is a **modified** copy of an
  Apache-2.0 NVIDIA source file; the modification is stated in its header, as
  Apache-2.0 section 4 requires.

Full text and the requested BSE citations are in `data/THIRD_PARTY_NOTICES.txt`.
This repository itself is MIT (`../LICENSE`); bundling permissively licensed
files alongside it is fine as long as their notices travel with them, which is
what the above arranges.
