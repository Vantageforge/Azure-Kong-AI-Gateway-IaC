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
