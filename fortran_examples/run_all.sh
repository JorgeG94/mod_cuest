#!/usr/bin/env bash
# Run all built Fortran cuEST examples.
#
# Usage:
#   ./run_all.sh [BUILD_DIR]
#
# Defaults:
#   BUILD_DIR  ./build
#
# Reads BUILD_DIR/examples.manifest, which CMake generates from the
# add_fortran_example() calls, so adding an example never means editing this
# script.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${1:-$SCRIPT_DIR/build}"
DATA_DIR="$SCRIPT_DIR/data"
MANIFEST="$BUILD_DIR/examples.manifest"

if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: build directory not found: $BUILD_DIR"
    echo "Build first:"
    echo "  cmake -S $SCRIPT_DIR -B $BUILD_DIR -DCUEST_LIB_DIR=<pkg>/lib"
    echo "  cmake --build $BUILD_DIR -j"
    exit 1
fi
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: $MANIFEST not found -- re-run cmake to regenerate it."
    exit 1
fi

# Input data, bundled in data/ (see data/THIRD_PARTY_NOTICES.txt).
XYZ="$DATA_DIR/geometry/h2o.xyz"
XYZ_ECP="$DATA_DIR/geometry/ch2i2.xyz"
GBS="$DATA_DIR/basis_set/def2-svp.gbs"
AUX_GBS="$DATA_DIR/basis_set/def2-universal-jkfit.gbs"
ECP_GBS="$DATA_DIR/basis_set/def2-svp-ecp.gbs"

# cuEST ships cubins for sm_80 and newer only. Volta gets a clear message here
# rather than an opaque CUEST_STATUS_UNSUPPORTED_ARCHITECTURE from every test.
CAP="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
if [ -n "${CAP:-}" ] && [ "$CAP" -lt 80 ] 2>/dev/null; then
    echo "WARNING: this GPU is sm_${CAP}; cuEST requires sm_80 or newer."
    echo "         Everything except the parser test will fail at cuestCreate."
    echo "         Use a Hopper or A100 node (Gadi: gpuhopper / dgxa100)."
    echo
fi

PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=()

echo "============================================================"
echo " cuEST Fortran examples"
echo " Build dir : $BUILD_DIR"
echo " Data dir  : $DATA_DIR"
echo "============================================================"
echo

while IFS='|' read -r name args; do
    [ -z "${name:-}" ] && continue
    exe="$BUILD_DIR/bin/$name"
    if [ ! -x "$exe" ]; then
        echo "[ SKIP ] $name  (not built)"
        SKIP=$((SKIP + 1))
        continue
    fi
    # Expand the @TOKEN@ placeholders recorded by CMake.
    args="${args//@XYZ_ECP@/$XYZ_ECP}"
    args="${args//@XYZ@/$XYZ}"
    args="${args//@AUX_GBS@/$AUX_GBS}"
    args="${args//@ECP_GBS@/$ECP_GBS}"
    args="${args//@GBS@/$GBS}"

    printf "[ RUN  ] %s\n" "$name"
    # shellcheck disable=SC2086
    if "$exe" $args; then
        echo "[ PASS ] $name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $name"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
    fi
    echo
done < "$MANIFEST"

# If the C reference was built, diff it against the Fortran port numerically.
ORACLE="$BUILD_DIR/bin/one_electron_integrals_oracle"
FPORT="$BUILD_DIR/bin/one_electron_integrals"
if [ -x "$ORACLE" ] && [ -x "$FPORT" ]; then
    echo "[ RUN  ] one_electron_integrals vs C reference"
    if "$ORACLE" "$XYZ" "$GBS" > "$BUILD_DIR/c.out" 2>&1 &&
       "$FPORT"  "$XYZ" "$GBS" > "$BUILD_DIR/f.out" 2>&1 &&
       python3 "$SCRIPT_DIR/compare.py" "$BUILD_DIR/c.out" "$BUILD_DIR/f.out"; then
        echo "[ PASS ] one_electron_integrals vs C reference"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] one_electron_integrals vs C reference"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("one_electron_integrals vs C reference")
    fi
    echo
else
    echo "[ SKIP ] C reference comparison (oracle not built)"
    echo "         configure with -DCUEST_INCLUDE_DIR and -DCUEST_SAMPLES_COMMON_DIR"
    SKIP=$((SKIP + 1))
    echo
fi

echo "============================================================"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
    printf ' Failed: %s\n' "${FAILED_NAMES[@]}"
fi
echo "============================================================"

[ "$FAIL" -eq 0 ]
