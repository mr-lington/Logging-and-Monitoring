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
