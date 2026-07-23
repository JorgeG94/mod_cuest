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
# Checked up front rather than per-comparison: if this helper is missing, every
# comparison short-circuits before compare.py runs and the summary reads as N
# numerical failures, which is a badly misleading way to report a missing file.
if [ ! -x "$SCRIPT_DIR/run_one.sh" ]; then
    echo "ERROR: $SCRIPT_DIR/run_one.sh is missing or not executable."
    echo "       It expands the @XYZ@/@GBS@ tokens from the manifest and is"
    echo "       required by both this script and the CTest comparisons."
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

# Every example that has a C reference is compared against it automatically;
# the list comes from CMake, so nothing here needs editing when one is added.
if [ -f "$BUILD_DIR/oracles.manifest" ]; then
    while read -r name; do
        [ -z "${name:-}" ] && continue
        fport="$BUILD_DIR/bin/$name"
        oracle="$BUILD_DIR/bin/${name}_oracle"
        if [ ! -x "$fport" ] || [ ! -x "$oracle" ]; then
            echo "[ SKIP ] $name vs C reference (not built)"
            SKIP=$((SKIP + 1)); continue
        fi
        echo "[ RUN  ] $name vs C reference"
        if "$SCRIPT_DIR/run_one.sh" "$BUILD_DIR" "$oracle" "$name" \
                > "$BUILD_DIR/$name.c.out" 2>&1 &&
           "$SCRIPT_DIR/run_one.sh" "$BUILD_DIR" "$fport"  "$name" \
                > "$BUILD_DIR/$name.f.out" 2>&1 &&
           python3 "$SCRIPT_DIR/compare.py" \
                "$BUILD_DIR/$name.c.out" "$BUILD_DIR/$name.f.out"; then
            echo "[ PASS ] $name vs C reference"
            PASS=$((PASS + 1))
        else
            echo "[ FAIL ] $name vs C reference"
            FAIL=$((FAIL + 1)); FAILED_NAMES+=("$name vs C reference")
        fi
        echo
    done < "$BUILD_DIR/oracles.manifest"
else
    echo "[ SKIP ] C reference comparisons (no oracles built)"
    SKIP=$((SKIP + 1)); echo
fi

echo "============================================================"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
    printf ' Failed: %s\n' "${FAILED_NAMES[@]}"
fi
echo "============================================================"

[ "$FAIL" -eq 0 ]
