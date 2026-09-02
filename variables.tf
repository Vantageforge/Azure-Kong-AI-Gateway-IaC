variable "resource_group_name" {
  description = "Name of the Azure resource group to create"
  type        = string
  default     = "kong-demo-rg"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "kong-demo-aks"
}

variable "node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v7"
}

variable "kong_namespace" {
  description = "Kubernetes namespace to deploy Kong into"
  type        = string
  default     = "kong"
}

variable "kong_image_repository" {
  description = "Container image for the Kong Gateway data plane"
  type        = string
  default     = "kong/kong-gateway"
}

variable "kong_image_tag" {
  description = "Kong Gateway image tag"
  type        = string
  default     = "3.15"
}

variable "kong_proxy_access_log" {
  description = "Destination for Kong proxy access logs. /dev/stdout lets the Datadog Agent collect them; set to \"off\" to disable."
  type        = string
  default     = "/dev/stdout"
}

variable "kong_proxy_error_log" {
  description = "Destination for Kong proxy error logs. /dev/stderr lets the Datadog Agent collect them."
  type        = string
  default     = "/dev/stderr"
}

variable "kong_status_listen" {
  description = "Address:port for Kong's status/metrics listener. Exposes /metrics (OpenMetrics) for the Datadog Agent to scrape."
  type        = string
  default     = "0.0.0.0:8100"
}

variable "kong_dns_stale_ttl" {
  description = "Kong dns_stale_ttl (seconds) as a string"
  type        = string
  default     = "3600"
}

variable "kong_resources_requests" {
  description = "Resource requests for the Kong data plane pod"
  type = object({
    cpu    = number
    memory = string
  })
  default = {
    cpu    = 1
    memory = "2Gi"
  }
}

variable "datadog_api_key" {
  description = <<-EOT
    Datadog API key (Organization Settings -> API Keys).
    Sensitive — set this via TF_VAR_datadog_api_key env var or a secrets
    manager rather than committing it in terraform.tfvars where possible.
  EOT
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site, e.g. datadoghq.com (US1), datadoghq.eu (EU1), us3.datadoghq.com (US3), us5.datadoghq.com (US5), ap1.datadoghq.com (AP1)"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_namespace" {
  description = "Kubernetes namespace to deploy the Datadog Agent into"
  type        = string
  default     = "datadog"
}

variable "kong_cert_path" {
  description = "Path to the Konnect-issued TLS certificate"
  type        = string
  default     = "./certs/tls.crt"
}

variable "kong_key_path" {
  description = "Path to the Konnect-issued TLS private key"
  type        = string
  default     = "./certs/tls.key"
}
