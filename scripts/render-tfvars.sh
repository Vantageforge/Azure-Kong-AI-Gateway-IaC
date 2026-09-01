#!/usr/bin/env bash
# CI-time renderer: turns GitHub Actions secrets into the local files
# Terraform expects (certs/tls.crt, certs/tls.key, ci.auto.tfvars.json),
# mirroring the shape documented in terraform.tfvars.example. Never echoes
# secret values; writes them straight to disk.
#
# Required env vars (set from GitHub Actions secrets/vars in the workflow):
#   KONG_TLS_CRT_B64                  base64-encoded Konnect mTLS client cert
#   KONG_TLS_KEY_B64                  base64-encoded Konnect mTLS client key
#   KONG_CLUSTER_CONTROL_PLANE        Konnect control-plane endpoint
#   KONG_CLUSTER_TELEMETRY_ENDPOINT   Konnect telemetry endpoint (no port)
#   KONG_CLUSTER_TELEMETRY_SERVER_NAME  usually same host as telemetry endpoint
#   DATADOG_API_KEY                   Datadog API key
#
# Optional env vars (defaults shown):
#   DATADOG_SITE       datadoghq.com
#   KONG_IMAGE_TAG      3.15

set -euo pipefail

: "${KONG_TLS_CRT_B64:?Set KONG_TLS_CRT_B64 (base64 mTLS client cert)}"
: "${KONG_TLS_KEY_B64:?Set KONG_TLS_KEY_B64 (base64 mTLS client key)}"
: "${KONG_CLUSTER_CONTROL_PLANE:?Set KONG_CLUSTER_CONTROL_PLANE}"
: "${KONG_CLUSTER_TELEMETRY_ENDPOINT:?Set KONG_CLUSTER_TELEMETRY_ENDPOINT}"
: "${KONG_CLUSTER_TELEMETRY_SERVER_NAME:?Set KONG_CLUSTER_TELEMETRY_SERVER_NAME}"
: "${DATADOG_API_KEY:?Set DATADOG_API_KEY}"
: "${DATADOG_SITE:=datadoghq.com}"
: "${KONG_IMAGE_TAG:=3.15}"

mkdir -p certs
umask 077

echo -n "${KONG_TLS_CRT_B64}" | base64 -d > certs/tls.crt
echo -n "${KONG_TLS_KEY_B64}" | base64 -d > certs/tls.key
echo "==> Wrote certs/tls.crt and certs/tls.key ($(wc -c < certs/tls.crt) / $(wc -c < certs/tls.key) bytes)"

jq -n \
  --arg image_tag "${KONG_IMAGE_TAG}" \
  --arg control_plane "${KONG_CLUSTER_CONTROL_PLANE}" \
  --arg telemetry_endpoint "${KONG_CLUSTER_TELEMETRY_ENDPOINT}:443" \
  --arg telemetry_server_name "${KONG_CLUSTER_TELEMETRY_SERVER_NAME}" \
  --arg datadog_api_key "${DATADOG_API_KEY}" \
  --arg datadog_site "${DATADOG_SITE}" \
  '{
    kong_helm_values: {
      ingressController: { enabled: false },
      image: { repository: "kong/kong-gateway", tag: $image_tag },
      secretVolumes: ["kong-cluster-cert"],
      env: {
        role: "data_plane",
        database: "off",
        konnect_mode: "on",
        vitals: "off",
        cluster_mtls: "pki",
        cluster_control_plane: $control_plane,
        cluster_telemetry_endpoint: $telemetry_endpoint,
        cluster_telemetry_server_name: $telemetry_server_name,
        cluster_cert: "/etc/secrets/kong-cluster-cert/tls.crt",
        cluster_cert_key: "/etc/secrets/kong-cluster-cert/tls.key",
        lua_ssl_trusted_certificate: "system",
        proxy_access_log: "off",
        dns_stale_ttl: "3600"
      },
      resources: { requests: { cpu: 1, memory: "2Gi" } },
      proxy: { enabled: true },
      admin: { enabled: false },
      manager: { enabled: false }
    },
    datadog_api_key: $datadog_api_key,
    datadog_site: $datadog_site
  }' > ci.auto.tfvars.json

echo "==> Wrote ci.auto.tfvars.json (auto-loaded by terraform, no -var-file needed)"
