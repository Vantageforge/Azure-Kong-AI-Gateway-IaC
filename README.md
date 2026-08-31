# Azure-Kong-AI-Gateway-IaC

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

## Sending logs, metrics, and traces to Datadog

This project deploys a **Datadog Agent** DaemonSet (logs, OpenMetrics scraping,
and an OTLP receiver for traces) alongside Kong. Two things live outside
Terraform because Konnect — not the Helm chart — owns plugin configuration
for Self-Managed Hybrid data planes:

1. **Enable the `prometheus` plugin** (metrics): Konnect → Gateway Manager →
   **Plugins → New Plugin → Prometheus**, scope: **Global**. This turns on
   the `/metrics` endpoint the Datadog Agent scrapes via the `podAnnotations`
   already set in `terraform.tfvars`.

2. **Enable the `opentelemetry` plugin** (traces): Konnect → **Plugins →
   New Plugin → OpenTelemetry**, scope: Global. Set the traces endpoint to
   the in-cluster Datadog Agent OTLP HTTP receiver:

   ```
   http://datadog.datadog.svc.cluster.local:4318/v1/traces
   ```

Logs need no extra plugin — Kong's access/error logs go to stdout/stderr
(`proxy_access_log` / `proxy_error_log` in `terraform.tfvars`) and the
Datadog Agent's `containerCollectAll` picks them up automatically, tagged
with `namespace:kong`.

Before applying, set your Datadog API key and site in `terraform.tfvars`
(or, preferably, export it instead of committing it):

```bash
export TF_VAR_datadog_api_key="<your-datadog-api-key>"
```

Verify in Datadog after `terraform apply`:
- **Logs → Live Tail**, filter `namespace:kong`
- **Metrics Explorer**, search `kong.*`
- **APM → Traces**, service `kong` (once the OpenTelemetry plugin is set)

## Terraform Logs
<img width="1659" height="713" alt="image" src="https://github.com/user-attachments/assets/e7cec337-03b3-46bc-b9b0-9f5f19be30e3" />
