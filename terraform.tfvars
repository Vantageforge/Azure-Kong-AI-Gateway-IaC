# terraform.tfvars
# Keep this file out of version control — it holds the Datadog API key and any
# environment-specific overrides. It's already excluded in .gitignore.

# Datadog Agent settings
datadog_api_key = "xxxx"
datadog_site    = "datadoghq.com"

# --- Optional Kong data plane overrides -------------------------------------
# Defaults live in variables.tf; the Konnect endpoints are pinned in
# kong-helm-values.tf. Uncomment only what you need to change.
# kong_image_tag          = "3.15"
# kong_proxy_access_log   = "/dev/stdout"
# kong_proxy_error_log    = "/dev/stderr"
# kong_status_listen      = "0.0.0.0:8100"
# kong_dns_stale_ttl      = "3600"
# kong_resources_requests = { cpu = 1, memory = "2Gi" }

# --- Optional cluster overrides — defaults live in variables.tf -------------
# resource_group_name = "kong-demo-rg"
# location             = "eastus"
# cluster_name         = "kong-demo-aks"
# node_count           = 2
# node_vm_size         = "Standard_D4s_v7"
