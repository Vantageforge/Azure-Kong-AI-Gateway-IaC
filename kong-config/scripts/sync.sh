#!/usr/bin/env bash
# Sync the rendered config for one environment to its Konnect control plane.
# Usage: scripts/sync.sh <environment>
#
# Same credential requirements as diff.sh. Prod additionally requires
# CONFIRM_PROD_SYNC=yes, so a stray `make kong-sync-prod` on a laptop can't
# push to production by accident — CI sets this explicitly after its own
# approval gate (see .github/workflows/kong-gateway-config.yml).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh
require_deck

ENVIRONMENT="${1:?usage: sync.sh <environment>}"
RENDERED_FILE="$KONG_CONFIG_DIR/.rendered/${ENVIRONMENT}.yaml"

: "${DECK_KONNECT_TOKEN:?DECK_KONNECT_TOKEN must be set (Konnect Personal Access Token)}"
: "${DECK_KONNECT_CONTROL_PLANE_NAME:?DECK_KONNECT_CONTROL_PLANE_NAME must be set (e.g. kong-aks-prod)}"

if [[ "$ENVIRONMENT" == "prod" && "${CONFIRM_PROD_SYNC:-}" != "yes" ]]; then
  echo "error: refusing to sync 'prod' without CONFIRM_PROD_SYNC=yes." >&2
  echo "       Run: CONFIRM_PROD_SYNC=yes scripts/sync.sh prod" >&2
  exit 1
fi

load_env "$ENVIRONMENT"
guard_placeholder_secrets "$ENVIRONMENT"
mkdir -p "$(dirname "$RENDERED_FILE")"
render_to "$RENDERED_FILE"

extra_flags=()
[[ -n "${DECK_KONNECT_ADDR:-}" ]] && extra_flags+=(--konnect-addr "$DECK_KONNECT_ADDR")

echo "--- deck file lint ---"
deck file lint -s "$RENDERED_FILE" "$KONG_CONFIG_DIR/rulesets/base.yaml"

echo "--- deck gateway diff (preview) ---"
deck gateway diff "$RENDERED_FILE" \
  --konnect-token "$DECK_KONNECT_TOKEN" \
  --konnect-control-plane-name "$DECK_KONNECT_CONTROL_PLANE_NAME" \
  "${extra_flags[@]}"

echo "--- deck gateway sync ---"
deck gateway sync "$RENDERED_FILE" \
  --konnect-token "$DECK_KONNECT_TOKEN" \
  --konnect-control-plane-name "$DECK_KONNECT_CONTROL_PLANE_NAME" \
  "${extra_flags[@]}"
