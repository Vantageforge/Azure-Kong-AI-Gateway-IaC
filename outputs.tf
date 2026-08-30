output "kube_config" {
  description = "Raw kubeconfig for the AKS cluster (write to a file and export KUBECONFIG)"
  value       = azurerm_kubernetes_cluster.kong.kube_config_raw
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the created AKS cluster"
  value       = azurerm_kubernetes_cluster.kong.name
}

output "resource_group_name" {
  description = "Name of the resource group containing the cluster"
  value       = azurerm_resource_group.kong.name
}

output "kong_namespace" {
  description = "Kubernetes namespace Kong was deployed into"
  value       = kubernetes_namespace.kong.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the Kong Helm release"
  value       = helm_release.kong.status
}
