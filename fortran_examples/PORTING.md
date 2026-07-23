# How to port a cuEST C sample to Fortran

Recipe for adding one sample. Read this before starting; `2_one_electron_integrals`
is the worked reference and is known to match the C output exactly.

## Paths

```
REPO = /scratch/bm55/jlv900/dev/mod_cuest
PKG  = /scratch/bm55/jlv900/dev/libcuest-linux-x86_64-0.2.0.4_cuda12-archive
C sample  = $PKG/CUDALibrarySamples/cuEST/c_examples/examples/<group>/<name>/main.c
C helpers = $PKG/CUDALibrarySamples/cuEST/c_examples/common/
```

## Build

```sh
module load gcc/13.2.0
module load cuda
cd $REPO/fortran_examples
cmake -S . -B <your-build-dir> -DCUEST_ROOT=$PKG
cmake --build <your-build-dir> -j8
```

**Use your own build directory** (e.g. `build-3_density_fitting`). Several ports
are developed concurrently and a shared build tree races.

## You cannot run what you build

This machine has a **V100 (sm_70)**. cuEST ships cubins for **sm_80+ only**, so
anything that creates a cuEST handle fails at `cuestCreate` with status `11`,
`CUEST_STATUS_UNSUPPORTED_ARCHITECTURE`. That is expected and is not a defect —
do not try to work around it, and do not report it as a bug.

Your acceptance criterion is therefore: **both the Fortran port and its C oracle
compile and link warning-free**. The numeric comparison happens later on an
H100. `test_parsers` is the one thing that does run here, since it creates no
cuEST handle.

## 1. The Fortran port

Put it at `<group>/<name>.f90`. Mirror the C sample **call for call** — same
objects created in the same order, same parameters objects, same workspace
query/allocate/call sequence. Use the shared helpers rather than re-implementing:

| helper | from `common/` |
|---|---|
| `cuest_check(status, what)`, `cuda_ck(code, what)` | `cuest_sample_utils` |
| `ws_alloc(ws, desc)` / `ws_free(ws)` | `cuest_sample_utils` |
| `dev_alloc(n)` / `dev_free(p)` / `dev_to_host(host, dev, n)` | `cuest_sample_utils` |
| `matrix_report` / `array_report` / `scalar_report` | `cuest_sample_utils` |
| `arg(i)` / `require_args(n, usage)` | `cuest_sample_utils` |
| `parse_xyz_file`, `ANGSTROM_TO_BOHR` | `xyz_parser` |
| `parse_gbs_for_element` | `gbs_parser` |
| `form_ao_shells`, `normalized_coefficients` | `ao_shells` |

cuEST idioms that bite (see `../CLAUDE.md` for the full list):

- **Every parameters object must be created**, even when it has no configurable
  parameters. Passing `c_null_ptr` returns `CUEST_STATUS_NULL_POINTER`.
- **Host vs device pointers are indistinguishable in the signature** — both are
  `type(c_ptr), value`. Shell exponents/coefficients and pair-list coordinates
  are HOST (`c_loc(...)`, needs `target`); integral outputs and densities are
  DEVICE. Getting it wrong is a segfault, not a status code.
- A **persistent** workspace must outlive the object it created; a temporary one
  can be freed immediately after the call.
- `C_LOC` needs a `TARGET` actual argument, and cannot take an array section
  directly — wrap it in a small subroutine that declares the dummy `target`
  (see `ao_shells.f90 :: create_shell`).

Compile warning-free under `-std=f2008 -Wall`.

## 2. The C oracle

The upstream samples compute results and exit **without printing them**, so
there is nothing to compare against. Fix that with the smallest possible change:

1. Copy `$PKG/.../<name>/main.c` to `oracle/<name>_oracle.c`.
2. Prepend the derivation header — copy the wording from
   `oracle/one_electron_integrals_oracle.c`. Apache-2.0 section 4 requires
   stating that the file is modified.
3. Add `#include "oracle_report.h"` after the other helper includes.
4. Add `oracle_report_matrix/array/scalar` calls where each result is available
   and still alive (before the buffer is freed).
5. **Change nothing else.** The value of the oracle is that its setup path is
   identical to upstream; if you rewrite it, it stops being a reference.

## 3. Matching output

`compare.py` matches sections by label, so the port and the oracle must emit
**the same sections, with the same labels, in the same order**:

| C | Fortran |
|---|---|
| `oracle_report_matrix("S (overlap)", d_S, nao)` | `call matrix_report("S (overlap)", h, nao)` |
| `oracle_report_array("gradient", d_g, 3*natoms)` | `call array_report("gradient", h, 3*natoms)` |
| `oracle_report_scalar("E_xc", e)` | `call scalar_report("E_xc", e)` |

The C helpers take a device *or* host pointer and copy as needed; the Fortran
ones take a host array, so `dev_to_host` first.

Pick labels that say what the quantity is. Report every distinct result the
sample computes — a quantity you do not print is a quantity nobody validates.

## 4. Register it

Add to your group's `CMakeLists.txt` **only**:

```cmake
add_fortran_example(<name> ${CMAKE_CURRENT_SOURCE_DIR}/<name>.f90 ARGS @XYZ@ @GBS@)
add_c_oracle(<name> ${CMAKE_SOURCE_DIR}/oracle/<name>_oracle.c)
```

`ARGS` must match how NVIDIA's `c_examples/run_all.sh` invokes that sample.
Available tokens: `@XYZ@`, `@XYZ_ECP@`, `@GBS@`, `@AUX_GBS@`, `@ECP_GBS@`.
Omit `ARGS` entirely for samples that take no arguments.

Everything else — the run script, the CTest cases, the comparison — picks it up
from the generated manifests automatically.

## 5. Do not touch

Other ports are being developed at the same time in this tree. Confine yourself
to your group directory and your own `oracle/<name>_oracle.c` files.

Off limits: `fortran_examples/CMakeLists.txt`, `compare.py`, `run_all.sh`,
`run_one.sh`, `cmake/`, `oracle/oracle_report.h`, anything outside
`fortran_examples/`, and any build directory that is not yours. Do not run
`git` commands. If you need a new **shared** helper in `common/`, create a new
file — never edit someone else's.
