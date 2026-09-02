terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# Resource Group + AKS Cluster
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "kong" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "kong" {
  name                = var.cluster_name
  location            = azurerm_resource_group.kong.location
  resource_group_name = azurerm_resource_group.kong.name
  dns_prefix          = "${var.cluster_name}-dns"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled = true

  tags = {
    project = "kong-aks-terraform"
  }
}

# ---------------------------------------------------------------------------
# Kubernetes & Helm providers, wired to the AKS cluster created above
# ---------------------------------------------------------------------------

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.kong.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.kong.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.kong.kube_config[0].cluster_ca_certificate)
  }
}

# ---------------------------------------------------------------------------
# Namespace + mTLS secret for the Data Plane <-> Control Plane connection
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "kong" {
  metadata {
    name = var.kong_namespace
  }
}

resource "kubernetes_secret" "kong_cluster_cert" {
  metadata {
    name      = "kong-cluster-cert"
    namespace = kubernetes_namespace.kong.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = file(var.kong_cert_path)
    "tls.key" = file(var.kong_key_path)
  }
}

# ---------------------------------------------------------------------------
# Kong Gateway Data Plane Helm release
# ---------------------------------------------------------------------------

resource "helm_release" "kong" {
  name       = "my-kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.kong.metadata[0].name

  values = [yamlencode(local.kong_helm_values)]

  depends_on = [kubernetes_secret.kong_cluster_cert]
}

# ---------------------------------------------------------------------------
# Datadog Agent — logs, metrics (OpenMetrics scrape of Kong), and traces (OTLP)
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "datadog" {
  metadata {
    name = var.datadog_namespace
  }
}

resource "kubernetes_secret" "datadog_api_key" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.datadog.metadata[0].name

  values = [yamlencode({
    datadog = {
      site                 = var.datadog_site
      apiKeyExistingSecret = kubernetes_secret.datadog_api_key.metadata[0].name
      clusterName          = var.cluster_name

      # Logs — auto-collects stdout/stderr from every pod, including Kong's
      # access/error logs once proxy_access_log/proxy_error_log point at
      # /dev/stdout and /dev/stderr in kong_helm_values.
      logs = {
        enabled             = true
        containerCollectAll = true
      }

      # Traces — Agent exposes an OTLP receiver that the Kong `opentelemetry`
      # plugin (enabled in Konnect) can export to.
      apm = {
        portEnabled = true
      }
      otlp = {
        receiver = {
          protocols = {
            grpc = { enabled = true }
            http = { enabled = true }
          }
        }
      }

      processAgent = {
        enabled           = true
        processCollection = true
      }
    }
  })]

  depends_on = [kubernetes_secret.datadog_api_key]
}
