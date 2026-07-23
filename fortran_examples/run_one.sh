#!/usr/bin/env bash
# Run one built example with the argument list CMake recorded for it.
#   run_one.sh <build_dir> <exe_path> <example_name>
set -uo pipefail
BUILD_DIR="$1"; EXE="$2"; NAME="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$SCRIPT_DIR/data"
args="$(grep -m1 "^${NAME}|" "$BUILD_DIR/examples.manifest" | cut -d'|' -f2-)"
args="${args//@XYZ_ECP@/$D/geometry/ch2i2.xyz}"
args="${args//@XYZ@/$D/geometry/h2o.xyz}"
args="${args//@AUX_GBS@/$D/basis_set/def2-universal-jkfit.gbs}"
args="${args//@ECP_GBS@/$D/basis_set/def2-svp-ecp.gbs}"
args="${args//@GBS@/$D/basis_set/def2-svp.gbs}"
# shellcheck disable=SC2086
exec "$EXE" $args
