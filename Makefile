.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Infrastructure (Terraform: AKS + Kong hybrid data plane + Datadog)
# ---------------------------------------------------------------------------

.PHONY: init plan apply destroy fmt validate
init:      ## terraform init (uses backend.hcl — copy from backend.hcl.example first)
	terraform init -backend-config=backend.hcl

fmt:       ## terraform fmt -recursive
	terraform fmt -recursive

validate: fmt  ## terraform validate
	terraform validate

plan: validate  ## terraform plan
	terraform plan

apply: validate  ## terraform apply
	terraform apply

destroy:   ## terraform destroy
	terraform destroy

# ---------------------------------------------------------------------------
# Gateway configuration (decK: Services / Routes / Plugins / Consumers)
# See kong-config/README.md for the full workflow.
# ---------------------------------------------------------------------------

.PHONY: kong-render-dev kong-render-staging kong-render-prod \
        kong-lint-dev kong-lint-staging kong-lint-prod \
        kong-diff-dev kong-diff-staging kong-diff-prod \
        kong-sync-dev kong-sync-staging kong-sync-prod

kong-render-dev:      ## Render the merged dev Kong config (no credentials needed)
	kong-config/scripts/render.sh dev

kong-render-staging:  ## Render the merged staging Kong config (no credentials needed)
	kong-config/scripts/render.sh staging

kong-render-prod:     ## Render the merged prod Kong config (no credentials needed)
	kong-config/scripts/render.sh prod

kong-lint-dev:        ## Lint the dev config against rulesets/base.yaml
	kong-config/scripts/lint.sh dev

kong-lint-staging:    ## Lint the staging config against rulesets/base.yaml
	kong-config/scripts/lint.sh staging

kong-lint-prod:       ## Lint the prod config against rulesets/base.yaml
	kong-config/scripts/lint.sh prod

kong-diff-dev:        ## Preview changes deck would sync to the dev control plane
	kong-config/scripts/diff.sh dev

kong-diff-staging:    ## Preview changes deck would sync to the staging control plane
	kong-config/scripts/diff.sh staging

kong-diff-prod:       ## Preview changes deck would sync to the prod control plane
	kong-config/scripts/diff.sh prod

kong-sync-dev:        ## Sync Services/Routes/Plugins/Consumers to the dev control plane
	kong-config/scripts/sync.sh dev

kong-sync-staging:    ## Sync Services/Routes/Plugins/Consumers to the staging control plane
	kong-config/scripts/sync.sh staging

kong-sync-prod:       ## Sync to the prod control plane (requires CONFIRM_PROD_SYNC=yes)
	kong-config/scripts/sync.sh prod

# ---------------------------------------------------------------------------

.PHONY: help
help:      ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
