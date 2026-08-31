# Azure-Kong-IaC

Provisions an AKS cluster and deploys a Kong Konnect Data Plane node
(Self-Managed Hybrid) into it — entirely as Terraform code. No manual
`az aks create`, `kubectl create secret`, or `helm install` steps.

## What this creates

- Azure Resource Group
- AKS cluster (`azurerm_kubernetes_cluster`)
- Kubernetes namespace (`kong`)
- TLS secret for Data Plane ↔ Control Plane mTLS
- Kong Gateway Helm release, configured as a data plane node

## Prerequisites

```bash
brew install terraform azure-cli kubectl
az login
az account set --subscription "<your-subscription-name-or-id>"
```

You also need a Kong Konnect account: https://konghq.com/products/kong-konnect

## Setup

1. In Kong Konnect: **Gateway Manager → New Gateway → Self-Managed Hybrid → Kubernetes**.
2. Download the generated certificate and key, and save them as:
   - `certs/tls.crt`
   - `certs/tls.key`
3. Note the **Control Plane endpoint** and **Telemetry endpoint** shown in Konnect.
4. Copy the example vars file and fill in your endpoints and any Helm chart
   overrides (image tag, resources, ingress, admin/manager API, etc.):

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   `kong_helm_values` in `terraform.tfvars` is passed straight through to the
   Kong Helm chart via `yamlencode()`, so it accepts the exact same keys as
   the chart's own `values.yaml` — `image`, `env`, `resources`, `proxy`,
   `admin`, `manager`, `ingressController`, `secretVolumes`, etc.

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

This provisions everything in one pass — roughly 8–12 minutes end to end.

## Connect kubectl

```bash
terraform output -raw kube_config > ~/.kube/kong-demo-config
export KUBECONFIG=~/.kube/kong-demo-config

kubectl get pods -n kong
kubectl get svc -n kong
```

Back in Kong Konnect → Gateway Manager, you should see **"Data Plane node found."**

## Test the proxy

```bash
kubectl get svc my-kong-kong-proxy -n kong
curl -i http://<EXTERNAL-IP>:80/<your-route-path>
```

(Create a Gateway Service + Route first in Konnect if you haven't yet.)

## Project layout

```
kong-aks-terraform/
├── main.tf                     # AKS cluster, namespace, secret, helm_release
├── variables.tf                # all input variables + defaults
├── outputs.tf                  # kubeconfig, cluster name, release status
├── terraform.tfvars.example    # copy to terraform.tfvars and fill in
├── .gitignore                  # excludes state, secrets, tfvars
└── certs/
    ├── README.md
    ├── tls.crt   (you provide this)
    └── tls.key   (you provide this)
```

## Teardown

```bash
terraform destroy
```
