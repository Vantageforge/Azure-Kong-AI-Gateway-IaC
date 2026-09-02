terraform {
  # Remote state in Azure Blob Storage. This is a PARTIAL configuration —
  # resource_group_name / storage_account_name / container_name / key and the
  # auth flags are supplied at `terraform init` time via `-backend-config`:
  #
  #   local CI-less use:  cp backend.hcl.example backend.hcl && edit it, then
  #                       `make init` (which passes -backend-config=backend.hcl)
  #   CI:                 the terraform-infra.yml workflow passes each value as
  #                       -backend-config="key=value" from repo variables
  #
  # The state storage account is created once by scripts/tf-backend-bootstrap.sh.
  backend "azurerm" {}
}
