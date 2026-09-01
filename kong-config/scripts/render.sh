#!/usr/bin/env bash
# Render base/**/*.yaml + an environment's values into one merged, fully
# resolved Kong declarative config file. Useful to eyeball exactly what
# would be sent to Konnect before running diff/sync.
#
# Usage: scripts/render.sh <environment> [output-file]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

ENVIRONMENT="${1:?usage: render.sh <environment> [output-file]}"
OUT_FILE="${2:-$KONG_CONFIG_DIR/.rendered/${ENVIRONMENT}.yaml}"

load_env "$ENVIRONMENT"
mkdir -p "$(dirname "$OUT_FILE")"
render_to "$OUT_FILE"

echo "Rendered $ENVIRONMENT -> $OUT_FILE"
