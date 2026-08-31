# terraform.tfvars
# Fill in / adjust as needed. Keep this file out of version control —
# it's already excluded in .gitignore since Konnect endpoints and other
# environment-specific details live here.

kong_helm_values = {
  ingressController = {
    enabled = false
  }

  image = {
    repository = "kong/kong-gateway"
    tag        = "3.15"
  }

  secretVolumes = ["kong-cluster-cert"]

  # Datadog Autodiscovery: scrapes Kong's OpenMetrics /metrics endpoint on
  # the status port. Requires the "prometheus" plugin enabled globally in
  # Konnect (Gateway Manager -> Plugins -> New Plugin -> Prometheus, scope: Global).
  podAnnotations = {
    "ad.datadoghq.com/proxy.checks" = <<-EOT
    {
      "openmetrics": {
        "init_config": {},
        "instances": [
          {
            "openmetrics_endpoint": "http://%%host%%:8100/metrics",
            "namespace": "kong",
            "metrics": [".*"]
          }
        ]
      }
    }
    EOT
  }

  env = {
    role         = "data_plane"
    database     = "off"
    konnect_mode = "on"
    vitals       = "off"
    cluster_mtls = "pki"

    cluster_control_plane          = "xxx"
    cluster_telemetry_endpoint     = "xxx"
    cluster_telemetry_server_name  = "xxxx"
    cluster_cert                   = "/etc/secrets/kong-cluster-cert/tls.crt"
    cluster_cert_key               = "/etc/secrets/kong-cluster-cert/tls.key"

    lua_ssl_trusted_certificate = "system"

    # Logs -> stdout/stderr so the Datadog Agent's container log collection
    # picks them up automatically. (Previously "off".)
    proxy_access_log = "/dev/stdout"
    proxy_error_log  = "/dev/stderr"

    # Exposes the /metrics (Prometheus/OpenMetrics) endpoint the Datadog
    # Agent scrapes, once the "prometheus" plugin is enabled in Konnect.
    status_listen = "0.0.0.0:8100"

    dns_stale_ttl = "3600"
  }

  resources = {
    requests = {
      cpu    = 1
      memory = "2Gi"
    }
  }

  proxy = {
    enabled = true
  }

  admin = {
    enabled = false
  }

  manager = {
    enabled = false
  }
}

# Datadog Agent settings
datadog_api_key = "xxxx"
datadog_site    = "datadoghq.com"

# Optional overrides for the cluster itself — defaults live in variables.tf
# resource_group_name = "kong-demo-rg"
# location             = "eastus"
# cluster_name         = "kong-demo-aks"
# node_count           = 2
# node_vm_size         = "Standard_DS2_v2"
