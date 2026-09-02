locals {
  # Full values tree passed to the Kong Helm chart. Environment-specific knobs
  # come from variables; the Konnect cluster endpoints are pinned here on
  # purpose (not variables) since they identify this specific control plane.
  kong_helm_values = {
    ingressController = {
      enabled = false
    }

    image = {
      repository = var.kong_image_repository
      tag        = var.kong_image_tag
    }

    secretVolumes = ["kong-cluster-cert"]

    # Datadog Autodiscovery: scrapes Kong's OpenMetrics /metrics endpoint on
    # the status port. Requires the "prometheus" plugin enabled globally in
    # Konnect (delivered via kong-config/base/plugins/global.yaml).
    podAnnotations = {
      "ad.datadoghq.com/proxy.checks" = jsonencode({
        openmetrics = {
          init_config = {}
          instances = [
            {
              openmetrics_endpoint = "http://%%host%%:8100/metrics"
              namespace            = "kong"
              metrics              = [".*"]
            }
          ]
        }
      })
    }

    env = {
      role         = "data_plane"
      database     = "off"
      konnect_mode = "on"
      vitals       = "off"
      cluster_mtls = "pki"

      # Konnect control plane + telemetry endpoints for this environment.
      cluster_control_plane         = "45fc0f7a62.us.cp.konghq.com"
      cluster_telemetry_endpoint    = "45fc0f7a62.us.tp.konghq.com:443"
      cluster_telemetry_server_name = "45fc0f7a62.us.tp.konghq.com"
      cluster_cert                  = "/etc/secrets/kong-cluster-cert/tls.crt"
      cluster_cert_key              = "/etc/secrets/kong-cluster-cert/tls.key"

      lua_ssl_trusted_certificate = "system"

      proxy_access_log = var.kong_proxy_access_log
      proxy_error_log  = var.kong_proxy_error_log
      status_listen    = var.kong_status_listen
      dns_stale_ttl    = var.kong_dns_stale_ttl
    }

    resources = {
      requests = {
        cpu    = var.kong_resources_requests.cpu
        memory = var.kong_resources_requests.memory
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
}
