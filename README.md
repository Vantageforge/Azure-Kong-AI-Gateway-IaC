# Azure-Kong-AI-Gateway-IaC

Provisions an AKS cluster and deploys a Kong Konnect Data Plane node
(Self-Managed Hybrid) into it, plus a Datadog Agent for logs, metrics, and
traces — entirely as Terraform code. No manual `az aks create`,
`kubectl create secret`, or `helm install` steps.

## Architecture

<img src="assets/architecture.svg" alt="Animated architecture diagram: Kong Konnect control plane synced with an AKS-hosted Kong data plane node and Datadog agent, proxying requests to a backend" width="700">
<img width="1000" height="900" alt="image" src="https://github.com/user-attachments/assets/3d347485-6aa1-42c3-bd1b-a71f4465b1b2" />

<details>
<summary>Text version</summary>

```
Kong Konnect (control plane)
        │  config sync ↓ / status ↑ (mTLS)
        ▼
Azure → Resource group → AKS cluster
        ├── Data plane node (self-managed)
        │       │  telemetry
        │       ▼
        │   Datadog agent
        │
        └── request  ──────────► Backend (upstream API)
```

</details>


**Control plane / data plane split:** Kong Konnect holds the managed
control plane. The AKS cluster runs the self-managed data plane node,
connected over mTLS. Konnect pushes down configuration (Routes, Services,
Plugins); the data plane node executes it and reports status back.

**Request flow:** a request enters the data plane node and is matched to a
Route, which runs any attached Plugins (this is where the Prometheus and
OpenTelemetry plugins execute), then is proxied via a Service to the
Backend upstream.

**Telemetry:** the same Plugins stage sends logs, metrics, and traces to
the Datadog agent, which runs alongside the data plane node in the same
AKS cluster (separate `datadog` namespace) — in parallel with the request
continuing on to the backend.

## What this creates

- Azure Resource Group
- AKS cluster (`azurerm_kubernetes_cluster`)
- Kubernetes namespace `kong` + TLS secret for Data Plane ↔ Control Plane mTLS
- Kong Gateway Helm release, configured as a data plane node
- Kubernetes namespace `datadog` + API key secret
- Datadog Agent DaemonSet (`datadog/datadog` Helm chart) — log collection,
  OpenMetrics scraping, OTLP receiver for traces, process agent

## Prerequisites

```bash
brew install terraform azure-cli kubectl
az login
az account set --subscription "<your-subscription-name-or-id>"
```

You'll also need:
- A Kong Konnect account: https://konghq.com/products/kong-konnect
- A Datadog account and API key: **Organization Settings → API Keys** at
  `https://app.datadoghq.com/organization-settings/api-keys`. Note your
  **Datadog site** too (visible in the URL — `datadoghq.com` for US1,
  `datadoghq.eu` for EU1, `us3.datadoghq.com` for US3, `us5.datadoghq.com`
  for US5, `ap1.datadoghq.com` for AP1).

## Setup

1. In Kong Konnect: **Gateway Manager → New Gateway → Self-Managed Hybrid → Kubernetes**.
2. Download the generated certificate and key, and save them as:
   - `certs/tls.crt`
   - `certs/tls.key`
3. Note the **Control Plane endpoint** and **Telemetry endpoint** shown in Konnect.
4. Copy the example vars file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Fill in your Konnect endpoints, and set the Datadog API key — preferably
   as an environment variable rather than committing it to the file:

   ```bash
   export TF_VAR_datadog_api_key="<your-datadog-api-key>"
   ```

   `kong_helm_values` in `terraform.tfvars` is passed straight through to the
   Kong Helm chart via `yamlencode()`, so it accepts the exact same keys as
   the chart's own `values.yaml` — `image`, `env`, `resources`, `proxy`,
   `admin`, `manager`, `ingressController`, `secretVolumes`, `podAnnotations`, etc.

   > Note: `.tfvars` files don't support function calls like `jsonencode()`.
   > The `podAnnotations` block uses a heredoc (`<<-EOT ... EOT`) with literal
   > JSON text instead — keep that pattern if you add more annotations.

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

This provisions everything in one pass — roughly 8–12 minutes end to end.
Re-running `terraform apply` after editing `kong_helm_values` triggers a
rolling restart of the Kong pod automatically (env vars and annotations only
take effect on a new pod, not the running one).

> **AKS SKU note:** the default `node_vm_size` is `Standard_D4s_v7`.
> Azure's allowed VM sizes vary by subscription/region — if you get a
> `BadRequest: VM size ... is not allowed` error, check the list Azure
> returns in the error and override `node_vm_size` in `terraform.tfvars`.

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
├── main.tf                     # AKS cluster, Kong namespace/secret/helm_release,
│                                # Datadog namespace/secret/helm_release
├── variables.tf                # all input variables + defaults
├── outputs.tf                  # kubeconfig, cluster name, release status
├── terraform.tfvars.example    # copy to terraform.tfvars and fill in
├── .gitignore                  # excludes state, secrets, tfvars
└── certs/
    ├── README.md
    ├── tls.crt   (you provide this)
    └── tls.key   (you provide this)
```

## Sending logs, metrics, and traces to Datadog

Two steps live **outside Terraform**, because for Self-Managed Hybrid data
planes, plugin configuration is owned by Konnect's control plane, not the
Helm chart:

1. **Enable the `prometheus` plugin** (metrics): Konnect → Gateway Manager →
   **Plugins → New Plugin → Prometheus**, scope: **Global** → Save. This
   turns on Kong's `/metrics` endpoint, which the `podAnnotations` already
   in `terraform.tfvars` tell the Datadog Agent to scrape via OpenMetrics.

2. **Enable the `opentelemetry` plugin** (traces): Konnect → **Plugins →
   New Plugin → OpenTelemetry**, scope: **Global**. Set the traces endpoint to
   the in-cluster Datadog Agent OTLP HTTP receiver:

   ```
   http://datadog.datadog.svc.cluster.local:4318/v1/traces
   ```

   Traces only start appearing for requests sent *after* this plugin is active.

Logs need no extra plugin. Kong's `KONG_PROXY_ACCESS_LOG` /
`KONG_PROXY_ERROR_LOG` env vars (set to `/dev/stdout` / `/dev/stderr` in
`terraform.tfvars`) make Kong write access/error logs to stdout, and the
Datadog Agent's `containerCollectAll` picks up every pod's stdout
automatically — no per-app config needed.

### Verifying it's working

**Confirm the Agent is running:**
```bash
kubectl get pods -n datadog -o wide
```
You should see one `datadog-xxxxx` agent pod per node plus a
`datadog-cluster-agent` pod, all `Running`.

**Confirm Kong is actually writing logs:**
```bash
kubectl logs -n kong -l app.kubernetes.io/instance=my-kong -c proxy --tail=20
```
Send a test request first (`curl` against the proxy) if this is empty.

**Confirm the OpenMetrics scrape is working:**
```bash
kubectl exec -it -n datadog \
  $(kubectl get pod -n datadog -l app.kubernetes.io/component=agent -o jsonpath='{.items[0].metadata.name}') \
  -c agent -- agent status | grep -A 15 openmetrics
```
Look for `Instance ID: openmetrics:kong:... [OK]` with a non-zero
`Metric Samples` count. This confirms Kong's `/metrics` endpoint is being
scraped successfully.

**Confirm the Logs Agent is enabled:**
```bash
kubectl exec -it -n datadog \
  $(kubectl get pod -n datadog -l app.kubernetes.io/component=agent -o jsonpath='{.items[0].metadata.name}') \
  -c agent -- agent status | grep -B2 -A 15 "Logs Agent"
```

**In the Datadog UI:**
- **Logs → Live Tail**, filter `kube_namespace:kong` (Datadog's standard
  namespace tag — not a plain `namespace:kong` guess).
- **Metrics → Explorer**, search `kong_` (the check reports Kong's raw
  Prometheus metric names like `kong_http_requests_total` under this
  prefix). If nothing shows immediately, check **Metrics → Summary**
  instead — it reflects new ingestion faster than Explorer's autocomplete.
- **APM → Traces**, service `kong` (only populated once the OpenTelemetry
  plugin is active and test traffic has been sent since).

### Common gotchas

- **Config changes not showing up in Datadog:** `terraform apply` must
  actually run again after editing `kong_helm_values` — check
  `terraform plan` shows pending changes to `helm_release.kong` first.
  Env vars and pod annotations only apply to a newly created pod.
- **`Error: Function calls not allowed` on `terraform init`:** `.tfvars`
  files can't call `jsonencode()` or similar functions — use a heredoc with
  literal JSON text instead (see the `podAnnotations` block).
- **`OIDCIssuerFeatureCannotBeDisabled` on `terraform apply`:** Azure now
  enables the OIDC issuer by default on new AKS clusters; `main.tf` sets
  `oidc_issuer_enabled = true` explicitly to avoid Terraform trying to
  "correct" that drift.
- **`A resource ... already exists` on `terraform apply`:** usually means
  you're applying from a fresh directory without the original
  `.terraform`/state, while the Azure/K8s resources from an earlier apply
  still exist. Either apply from the original working directory, or
  `terraform import` the existing resources back into state.

## Teardown

```bash
terraform destroy
```
