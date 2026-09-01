#!/usr/bin/env bash
# One-time bootstrap for the Terraform remote state backend.
#
# Creates (if missing) the Azure resource group, storage account, and blob
# container that hold Terraform state for this project, with blob versioning
# and soft-delete enabled so a bad `apply` or accidental overwrite can be
# recovered. Uses Azure AD (RBAC) auth for blob access — no storage account
# key is generated or stored anywhere.
#
# Run this ONCE per environment, by someone with Owner/Contributor rights on
# the target subscription. It is not part of CI.
#
# Usage:
#   TF_STATE_RESOURCE_GROUP=kong-tfstate-rg \
#   TF_STATE_STORAGE_ACCOUNT=kongtfstateXXXX \
#   TF_STATE_CONTAINER=tfstate \
#   TF_STATE_LOCATION=eastus \
#   bash scripts/bootstrap-terraform-backend.sh
#
# TF_STATE_STORAGE_ACCOUNT must be globally unique, 3-24 lowercase
# alphanumeric characters (Azure storage account naming rules).

set -euo pipefail

: "${TF_STATE_RESOURCE_GROUP:?Set TF_STATE_RESOURCE_GROUP, e.g. kong-tfstate-rg}"
: "${TF_STATE_STORAGE_ACCOUNT:?Set TF_STATE_STORAGE_ACCOUNT, e.g. kongtfstateXXXX (globally unique)}"
: "${TF_STATE_CONTAINER:=tfstate}"
: "${TF_STATE_LOCATION:=eastus}"

echo "==> Resource group: ${TF_STATE_RESOURCE_GROUP} (${TF_STATE_LOCATION})"
az group create \
  --name "${TF_STATE_RESOURCE_GROUP}" \
  --location "${TF_STATE_LOCATION}" \
  --output none

echo "==> Storage account: ${TF_STATE_STORAGE_ACCOUNT}"
az storage account create \
  --name "${TF_STATE_STORAGE_ACCOUNT}" \
  --resource-group "${TF_STATE_RESOURCE_GROUP}" \
  --location "${TF_STATE_LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo "==> Enabling blob versioning + soft delete"
az storage account blob-service-properties update \
  --account-name "${TF_STATE_STORAGE_ACCOUNT}" \
  --resource-group "${TF_STATE_RESOURCE_GROUP}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output none

echo "==> Container: ${TF_STATE_CONTAINER} (Azure AD auth, no account key used)"
az storage container create \
  --name "${TF_STATE_CONTAINER}" \
  --account-name "${TF_STATE_STORAGE_ACCOUNT}" \
  --auth-mode login \
  --output none

cat <<EOF

Done. Remote state backend is ready:

  resource_group_name  = ${TF_STATE_RESOURCE_GROUP}
  storage_account_name = ${TF_STATE_STORAGE_ACCOUNT}
  container_name        = ${TF_STATE_CONTAINER}
  key                   = kong-aks.tfstate

Next steps:
  1. Grant "Storage Blob Data Contributor" on this storage account to
     whoever/whatever runs terraform (your own account for local use,
     and the GitHub Actions OIDC app registration for CI):

     az role assignment create \\
       --role "Storage Blob Data Contributor" \\
       --assignee "<principal-id-or-app-id>" \\
       --scope "$(az storage account show -n "${TF_STATE_STORAGE_ACCOUNT}" -g "${TF_STATE_RESOURCE_GROUP}" --query id -o tsv)"

  2. Set these as repo Variables in GitHub (Settings -> Secrets and
     variables -> Actions -> Variables) so the CI workflow can pass
     them as -backend-config values:

     TF_STATE_RESOURCE_GROUP=${TF_STATE_RESOURCE_GROUP}
     TF_STATE_STORAGE_ACCOUNT=${TF_STATE_STORAGE_ACCOUNT}
     TF_STATE_CONTAINER=${TF_STATE_CONTAINER}

  3. Locally, export the same three env vars before running
     "make init" (see README.md).
EOF
