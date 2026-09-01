#!/usr/bin/env bash
# Lint a rendered environment config against rulesets/base.yaml.
# Usage: scripts/lint.sh <environment>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh
require_deck

ENVIRONMENT="${1:?usage: lint.sh <environment>}"
RENDERED_FILE="$KONG_CONFIG_DIR/.rendered/${ENVIRONMENT}.yaml"

load_env "$ENVIRONMENT"
mkdir -p "$(dirname "$RENDERED_FILE")"
render_to "$RENDERED_FILE"

deck file lint -s "$RENDERED_FILE" "$KONG_CONFIG_DIR/rulesets/base.yaml"
