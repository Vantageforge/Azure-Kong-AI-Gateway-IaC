#!/usr/bin/env bash
# Shared helpers sourced by every script in this directory. Not meant to be
# run directly.
set -euo pipefail

KONG_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILES=(
  "$KONG_CONFIG_DIR"/base/services/*.yaml
  "$KONG_CONFIG_DIR"/base/routes/*.yaml
  "$KONG_CONFIG_DIR"/base/plugins/*.yaml
  "$KONG_CONFIG_DIR"/base/consumers.yaml
)

require_deck() {
  if ! command -v deck >/dev/null 2>&1; then
    echo "error: deck CLI not found on PATH. Install it: https://developer.konghq.com/deck/installation/" >&2
    exit 1
  fi
}

# usage: load_env <environment-name>
# Exports every DECK_* var from environments/<env>.env into the current
# shell — but only as a DEFAULT. A variable that's already set (e.g. a
# real secret injected by CI via the workflow's `env:` block) is left
# alone. A plain `source` would do an unconditional assignment and
# silently clobber that real secret with the file's committed placeholder
# value ("changeme-in-ci"), which defeats the whole point of injecting it
# in the first place — see guard_placeholder_secrets below, which only
# works correctly once this doesn't happen.
load_env() {
  local env_name="${1:?usage: load_env <environment>}"
  local env_file="$KONG_CONFIG_DIR/environments/${env_name}.env"
  if [[ ! -f "$env_file" ]]; then
    echo "error: no such environment '$env_name' (expected $env_file)" >&2
    echo "available environments:" >&2
    ls "$KONG_CONFIG_DIR"/environments/*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$//' | sed 's/^/ - /' >&2
    exit 1
  fi
  local key value
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    if [[ -z "${!key+x}" ]]; then
      export "$key=$value"
    fi
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$env_file")
}

# Fail fast on placeholder secrets outside dev. Only called before commands
# that actually talk to a live Konnect control plane (diff/sync) — render
# and lint intentionally skip this so they keep working in CI with no
# secrets at all, which is the point of validating structure before
# credentials are ever involved.
guard_placeholder_secrets() {
  local env_name="${1:?usage: guard_placeholder_secrets <environment>}"
  if [[ "$env_name" == "dev" ]]; then
    return 0
  fi
  for var in DECK_ADMIN_CONSOLE_API_KEY DECK_PARTNER_HMAC_USERNAME DECK_PARTNER_HMAC_SECRET; do
    if [[ "${!var:-}" == "changeme-in-ci" ]]; then
      echo "error: $var is still the placeholder value for environment '$env_name'." >&2
      echo "  Set real secrets via your CI secret store before diffing/syncing this environment." >&2
      exit 1
    fi
  done
}

render_to() {
  local out_file="${1:?usage: render_to <output-file>}"
  require_deck
  deck file render "${STATE_FILES[@]}" --populate-env-vars -o "$out_file"
}
