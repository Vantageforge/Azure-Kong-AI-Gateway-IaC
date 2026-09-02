#!/usr/bin/env bash
# One-time setup of the Terraform remote-state backend: a dedicated resource
# group + storage account + blob container, with RBAC (no account keys) and
# blob versioning for state history.
#
# Idempotent — safe to re-run. Requires an `az login` identity with permission
# to create resource groups and assign roles in the target subscription.
#
# Usage:
#   TFSTATE_STORAGE_ACCOUNT=mytfstate12345 ./scripts/tf-backend-bootstrap.sh
#
# Optional env vars (defaults shown):
#   TFSTATE_RESOURCE_GROUP=tfstate-rg
#   TFSTATE_CONTAINER=tfstate
#   LOCATION=eastus
#   CI_PRINCIPAL_ID=          # object id of the GitHub OIDC service principal;
#                             # if set, it's also granted access to the state
set -euo pipefail

RG="${TFSTATE_RESOURCE_GROUP:-tfstate-rg}"
SA="${TFSTATE_STORAGE_ACCOUNT:?set TFSTATE_STORAGE_ACCOUNT to a globally-unique name (3-24 lowercase alphanumeric)}"
CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
LOCATION="${LOCATION:-eastus}"

echo "==> Subscription: $(az account show --query name -o tsv) ($(az account show --query id -o tsv))"
echo "==> Resource group: $RG / Storage account: $SA / Container: $CONTAINER / Location: $LOCATION"

az group create --name "$RG" --location "$LOCATION" --output none

if ! az storage account show --name "$SA" --resource-group "$RG" --output none 2>/dev/null; then
  az storage account create \
    --name "$SA" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --output none
fi

# Blob versioning — keeps a history of every state write.
az storage account blob-service-properties update \
  --account-name "$SA" \
  --resource-group "$RG" \
  --enable-versioning true \
  --output none

SA_ID="$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)"

grant_blob_contributor() {
  local principal="$1"
  az role assignment create \
    --assignee-object-id "$principal" \
    --assignee-principal-type "$2" \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" \
    --output none 2>/dev/null || true
}

CALLER_ID="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
if [[ -n "$CALLER_ID" ]]; then
  echo "==> Granting current user Storage Blob Data Contributor on $SA"
  grant_blob_contributor "$CALLER_ID" "User"
fi

if [[ -n "${CI_PRINCIPAL_ID:-}" ]]; then
  echo "==> Granting CI principal $CI_PRINCIPAL_ID Storage Blob Data Contributor on $SA"
  grant_blob_contributor "$CI_PRINCIPAL_ID" "ServicePrincipal"
fi

# Container creation uses the caller's AAD identity (role assignment above may
# take a few seconds to propagate).
echo "==> Creating container $CONTAINER (retrying while RBAC propagates)"
for attempt in $(seq 1 12); do
  if az storage container create \
    --name "$CONTAINER" \
    --account-name "$SA" \
    --auth-mode login \
    --output none 2>/dev/null; then
    break
  fi
  [[ $attempt -eq 12 ]] && { echo "error: could not create container after retries" >&2; exit 1; }
  sleep 10
done

cat <<EOF

Backend ready. Use these values:

  # backend.hcl (local) — copy from backend.hcl.example
  resource_group_name  = "$RG"
  storage_account_name = "$SA"
  container_name       = "$CONTAINER"
  key                  = "infra.tfstate"
  use_azuread_auth     = true

  # GitHub repo Variables (Settings -> Secrets and variables -> Actions -> Variables)
  TFSTATE_RESOURCE_GROUP  = $RG
  TFSTATE_STORAGE_ACCOUNT = $SA
  TFSTATE_CONTAINER        = $CONTAINER
EOF
