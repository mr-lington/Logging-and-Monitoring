# EKS Kubernetes Observability Stack (Prometheus + Grafana + Loki) — Terraform + Helm

This project is a **production-style Kubernetes monitoring + logging setup** deployed on **Amazon EKS** using a security-first approach:

 Infrastructure as Code (Terraform)  
 Kubernetes GitOps-style deployments (Helm charts)  
 Metrics monitoring (Prometheus / kube-prometheus-stack)  
 Centralized logging (Grafana Loki with S3 backend)  
 Visualization + SRE correlation dashboard (Grafana: metrics + logs in one view)  
 Demo workload + synthetic traffic generation to validate observability  

> This repo is part of my **DevOps / Cloud Engineering Portfolio**, showing real-world deployment + troubleshooting skills.

---

##  Architecture Overview

### Metrics Flow (Prometheus)
EKS Nodes/Pods → kube-state-metrics + node-exporter → Prometheus → Grafana dashboards

### Logging Flow (Loki)
Pods logs → Alloy (log collector) → Loki → **S3 storage** → Grafana Explore/Dashboard

---

##  Tech Stack

| Layer | Tool |
|------|------|
| Cloud | AWS (EKS, VPC, IAM, S3, KMS) |
| IaC | Terraform |
| Metrics | Prometheus (kube-prometheus-stack) |
| Visualization | Grafana |
| Logs | Loki (single-binary + gateway) |
| Log agent | Alloy |
| Storage | S3 (Loki log storage) |
| Security | AWS Pod Identity |

---

##  Features Implemented

###  Observability (Metrics + Logs)
- **Prometheus**
  - CPU usage per pod
  - Memory usage per pod
  - Pod restarts
  - Node readiness/health
  - Kubernetes cluster resource usage

- **Loki**
  - Logs by namespace + pod
  - Search logs for patterns (`error`, `fail`, `panic`)
  - Logs from both application and kube-system

- **Grafana**
  - Integrated SRE-style dashboard
  - Pod selection dropdown
  - Logs + metrics correlation panels

---

#  Project Structure (Example)

```bash
Logging-and-Monitoring/
│
├── netwoking/                   # Terraform IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── sso.tf                   # SSO -> EKS access
│   ├── loki-s3-iam.tf           # IAM policy + Pod Identity
│
├── loki/                         # Loki Helm Values
│   ├── loki-values.yaml
│
├── prometheus/                   # kube-prometheus-stack values
│   ├── prometheus-values.yaml
│
├── test/
│   ├── app.yaml                  # nginx demo app
│
└── scripts/
    ├── start.sh                  # bootstrap setup script
```
##  Deployment Guide

###  Prerequisites

 AWS CLI configured  (this setup uses SSO)
 AWS IAM Identity Center SSO profile available  
 Terraform installed  
 kubectl installed  
 Helm installed  

### Export AWS environment variables

```bash
export AWS_PROFILE=lington
export AWS_SDK_LOAD_CONFIG=1
export AWS_REGION=eu-west-3
```
```bash
# needed for SSO
export AWS_PROFILE="$AWS_PROFILE"
export AWS_SDK_LOAD_CONFIG=1
# needed for loki Helm chart values.yam
export AWS_REGION="$AWS_REGION"
export LOKI_BUCKET_NAME="$BUCKET_NAME"
# export s3 variable.tf for loki
export TF_VAR_bucket_name="$BUCKET_NAME"
```
##  Terraform Deploy (EKS + IAM + VPC + Pod Identity)

```bash
cd netwoking
terraform fmt
terraform validate
terraform apply -auto-approve
```
##  Connect kubectl to the EKS cluster

```bash
aws eks update-kubeconfig \
  --name monitoring-logging4-demo-eks \
  --region eu-west-3 \
  --profile lington
```
## verify
```bash
kubectl get nodes
kubectl get ns
```
## Deploy Loki (Logs)

Add Grafana Helm repo and update:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```
```bash
helm install loki grafana/loki --namespace monitoring --create-namespace --values ./loki/loki-values.yaml
```
## verify Loki
```bash
kubectl get pods -n monitoring | grep loki
kubectl get svc -n monitoring | grep loki
```
## Deploy Prometheus + Grafana (Metrics)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values ./prometheus/prometheus-values.yaml
```
## verify
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```
##  Access Grafana + Prometheus

###  Grafana Port-forward

Check the Grafana service name:

```bash
kubectl get svc -n monitoring | grep -i grafana
```
## Port-forward Grafana to your local machine:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Now open in browser:

- http://localhost:3000

Login:

- **Username:** `admin`
- **Password:** *(whatever you set in your `values.yaml`, e.g. `admin12345`)*

---

###  Prometheus Port-forward

Check Prometheus service name:

```bash
kubectl get svc -n monitoring | grep -i prometheus
```
### Port-forward Prometheus:
```bash
kubectl port-forward -n monitoring svc/prometheus-prometheus-kube-prometheus-prometheus 9090:9090
```
Now open in browser:

- http://localhost:9090

##  Demo App Deployment (Validation Workload)

###  Deploy NGINX demo app
```bash
kubectl apply -f ./test/app.yaml
```
### Verify deployment
```bash
kubectl get pods -n demo
kubectl get svc -n demo
```
### Generate Load (Traffic)
```bash
kubectl run -n demo load-spike --rm -it --restart=Never \
  --image=curlimages/curl -- \
  sh -c 'while true; do curl -s -o /dev/null http://nginx-demo-svc.demo.svc.cluster.local; sleep 1; done'
```
This generates continuous requests so:
- Prometheus shows CPU/memory usage
- Loki shows HTTP GET logs
## Grafana Explore Queries
### Loki log query (demo namespace)
```bash
{namespace="demo"} |= "GET /"
```
### Logs per selected pod
```bash
{namespace="$namespace", pod=~"$pod"} |= "$search"
```
## Best PromQL Queries (Prometheus)
### Top pods by CPU
```bash
topk(10,
  sum(rate(container_cpu_usage_seconds_total{namespace!="",container!="POD"}[5m]))
  by (namespace, pod)
)
```
### Top pods by memory
```bash
topk(10,
  sum(container_memory_working_set_bytes{namespace!="",container!="POD"})
  by (namespace, pod)
)
```
### Restarts (last 1h)
```bash
sum(increase(kube_pod_container_status_restarts_total[1h]))
```
### Node readiness
```bash
sum(kube_node_status_condition{condition="Ready",status="true"})
```
## Loki LogQL Correlation Queries
### Error log rate per pod
This is the correct LogQL metric query:
```bash
sum by (pod) (
  rate({namespace="$namespace", pod=~"$pod"} |~ "(?i)error|fail|panic|exception" [5m])
)
```
Total log volume per namespace
```bash
sum by (namespace) (
  rate({namespace!=""}[5m])
)
```
## Troubleshooting (Real Issues Fixed)
This project intentionally documents real problems and fixes — showing practical DevOps troubleshooting ability.
### 1) Terraform asked for var.bucket_name every time
Cause: variable wasn’t exported properly.
Wrong:
```bash
export TF_VAR_bucket-name= "$BUCKET_NAME"
```
Fix: Terraform variables must be valid identifiers → use underscore:
```bash
export TF_VAR_bucket_name="$BUCKET_NAME"
```
### 2) Port-forward error: bind: Only one usage of each socket address
Cause: Another process already used port 9090
Fix: use different local port:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090
```
Or kill existing PID using PowerShell:
```bash
Stop-Process -Id 25376 -Force
```
### 3) Load generator couldn’t connect
Busybox wget timed out, but Curl worked.
Fix: Use curl container:
```bash
kubectl run -n demo load-spike --rm -it --restart=Never --image=curlimages/curl -- \
  sh -c 'while true; do curl -s -o /dev/null http://nginx-demo-svc.demo.svc.cluster.local; sleep 1; done'
```
or
```bash
kubectl run -n demo test --rm -it --restart=Never \
  --image=curlimages/curl -- sh -c "curl -v --max-time 5 http://nginx-demo-svc.demo.svc.cluster.local"
```
### 4) LogQL error rate panel parse error (COUNT_OVER_TIME unexpected)
Cause: Panel was created as Loki but using PromQL-style syntax (incorrect nesting).
Correct approach uses Loki metric functions directly:
```bash
sum by (pod) (
  rate({namespace="$namespace", pod=~"$pod"} |~ "(?i)error|fail|panic|exception" [5m])
)
```
### 5) Loki failed flushing to S3 (403 AccessDenied)
Cause: Pod Identity role missing correct S3 permissions
Fix:
- Terraform IAM policy must allow s3:PutObject on bucket objects:
- arn:aws:s3:::BUCKET/*
- Ensure role attached + pod identity association correct
- Restart Loki after policy fix
Useful Loki check:
```bash
kubectl logs -n monitoring loki-0 --tail=50
```
## Cost Saving Considerations (AWS)
This stack can become expensive at scale, so several cost controls were considered:
EKS managed node group with small instance size for labs
S3 as Loki storage backend (cheap durable storage)
Single binary Loki (instead of microservices mode)
Avoided provisioning:
- Dedicated monitoring EC2 servers
- Self-managed Prometheus servers
Recommended further optimizations:
- Add Cluster Autoscaler / Karpenter
- Use Spot instances for non-production node groups
- Reduce Loki retention periods
- Enable S3 lifecycle rules → Glacier / IA
## Why This Project Matters
This project demonstrates:
Real-world AWS EKS deployment
Secure IAM Pod Identity integration
Production-ready monitoring setup
Logging pipeline with long-term storage (S3)
Troubleshooting ability (Terraform, Helm, Grafana, Loki queries)
SRE-grade correlation: metrics + logs in one dashboard
## Author
### Darlington Imade
DevOps / Cloud Engineer
GitHub: https://github.com/mr-lington

LinkedIn: https://linkedin.com/in/darlingtonimade

![grafana 1](https://github.com/user-attachments/assets/ae7b56d0-a4d1-480d-b958-d874baf1133d)

![grafana 2 prometheus](https://github.com/user-attachments/assets/df030df8-9745-4f1e-a9bb-35ad230bbdd8)
![prometheus 1](https://github.com/user-attachments/assets/00352ccc-55fc-4ce3-aa4a-bd50ab7b4d8f)
![dash 1](https://github.com/user-attachments/assets/aaad4780-4887-408c-8121-499270c39d97)
![dash 2](https://github.com/user-attachments/assets/6f78d5ce-4831-4983-8bb0-5dcbd4d24cbf)
![dash 1](https://github.com/user-attachments/assets/8e44a92c-ddf0-445e-9780-26adc492e1ae)
![dash 3](https://github.com/user-attachments/assets/e057f317-52b4-4bba-abe4-67d7e9f5a698)

