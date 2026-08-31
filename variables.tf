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

variable "kong_helm_values" {
  description = <<-EOT
    Full values passed to the Kong Helm chart, in the same shape as the
    chart's own values.yaml (image, env, resources, proxy, admin, manager,
    ingressController, secretVolumes, etc). Passed through as-is via
    yamlencode(), so any key the chart supports can go here.
  EOT
  type = any
}

variable "datadog_api_key" {
  description = <<-EOT
    Datadog API key (Organization Settings -> API Keys).
    Sensitive — set this via TF_VAR_datadog_api_key env var or a secrets
    manager rather than committing it in terraform.tfvars where possible.
  EOT
  type      = string
  sensitive = true
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
