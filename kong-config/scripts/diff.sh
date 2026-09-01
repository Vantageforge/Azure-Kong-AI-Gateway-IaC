#!/usr/bin/env bash
# Show what `sync.sh` would change in Konnect, without changing anything.
# Usage: scripts/diff.sh <environment>
#
# Requires DECK_KONNECT_TOKEN (a Konnect Personal Access Token) and
# DECK_KONNECT_CONTROL_PLANE_NAME to be set in the calling shell/CI job —
# these are credentials, so they're never read from environments/*.env.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh
require_deck

ENVIRONMENT="${1:?usage: diff.sh <environment>}"
RENDERED_FILE="$KONG_CONFIG_DIR/.rendered/${ENVIRONMENT}.yaml"

: "${DECK_KONNECT_TOKEN:?DECK_KONNECT_TOKEN must be set (Konnect Personal Access Token)}"
: "${DECK_KONNECT_CONTROL_PLANE_NAME:?DECK_KONNECT_CONTROL_PLANE_NAME must be set (e.g. kong-aks-dev)}"

load_env "$ENVIRONMENT"
guard_placeholder_secrets "$ENVIRONMENT"
mkdir -p "$(dirname "$RENDERED_FILE")"
render_to "$RENDERED_FILE"

extra_flags=()
[[ -n "${DECK_KONNECT_ADDR:-}" ]] && extra_flags+=(--konnect-addr "$DECK_KONNECT_ADDR")

deck gateway diff "$RENDERED_FILE" \
  --konnect-token "$DECK_KONNECT_TOKEN" \
  --konnect-control-plane-name "$DECK_KONNECT_CONTROL_PLANE_NAME" \
  "${extra_flags[@]}"
