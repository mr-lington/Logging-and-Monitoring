#!/bin/bash
#set -euo pipefail

=== Config ===
BUCKET_NAME="eks-loki-bucket0070000"
AWS_REGION="eu-west-3"
AWS_PROFILE="lington"
CLUSTER_NAME="monitoring-logging5-demo-eks"   # do same in locals for env and eks name

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KMS_ALIAS_NAME="alias/eks/$CLUSTER_NAME"

echo ">> Using profile: $AWS_PROFILE, region: $AWS_REGION"
echo ">> Script root: $ROOT_DIR"

# AWS SSO Login
echo ">> Logging into AWS SSO for profile: $AWS_PROFILE"
aws sso logout >/dev/null 2>&1 || true
aws sso login --profile "$AWS_PROFILE"

# needed for SSO
export AWS_PROFILE="$AWS_PROFILE"
export AWS_SDK_LOAD_CONFIG=1
# needed for loki Helm chart values.yam
export AWS_REGION="$AWS_REGION"
export LOKI_BUCKET_NAME="$BUCKET_NAME"
# export s3 variable.tf for loki
export TF_VAR_bucket_name="$BUCKET_NAME"


# Clean up existing KMS alias (if any exist)
echo ">> Checking/removing existing KMS alias (if present): $KMS_ALIAS_NAME"
aws kms delete-alias \
  --alias-name "$KMS_ALIAS_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  2>/dev/null && \
  echo "   -> Old KMS alias deleted (it existed before)." || \
  echo "   -> No existing alias to delete or not required, continuing..."

# Create/ensure S3 bucket for Terraform state
echo ">> Creating S3 bucket for Terraform state: $BUCKET_NAME (region: $AWS_REGION)"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION" \
  2>/dev/null && \
  echo "   -> Bucket created." || \
  echo "   -> Bucket may already exist, continuing..."

echo ">> Enabling versioning on bucket: $BUCKET_NAME"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --versioning-configuration Status=Enabled

# Terraform – networking + EKS
cd "$ROOT_DIR/netwoking"

terraform init -upgrade
terraform fmt
terraform validate
terraform apply -auto-approve

# Configure kubectl for EKS cluster
cd "$ROOT_DIR"

echo ">> Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME" \
  --profile "$AWS_PROFILE"

echo ">> Verifying cluster connectivity..."
kubectl cluster-info
kubectl get nodes



echo ">> Deploying monitoring stacks alloy, grafana and prometheus"
# choco install kubernetes-helm   #this is for windons find the one suitable for your os
kubectl apply -f "$ROOT_DIR/loki/storageclass.yaml"
kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl create namespace monitoring
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki --namespace monitoring --values "$ROOT_DIR/loki/loki-values.yaml"
# Get Grafana 'admin' user password by running saved to grafana.txt
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d >> grafana.txt
helm upgrade --install alloy grafana/alloy -n monitoring -f "$ROOT_DIR/loki/alloy-values.yaml"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --values "$ROOT_DIR/prometheus/prometheus-values.yaml"
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
# access grafana at local host 3000
# access grafana at local host 9090
kubectl create namespace demo
kubectl apply -f "$ROOT_DIR/test/app.yaml"
# spike up load on the app
kubectl run -n demo load-spike --rm -it --restart=Never --image=curlimages/curl -- \
  sh -c 'while true; do curl -s -o /dev/null http://nginx-demo-svc.demo.svc.cluster.local; sleep 1; done'


# # post and query logs
# curl -H "Content-Type: application/json" -XPOST -s \
# "http://127.0.0.1:3100/loki/api/v1/push" \
# -H "X-Scope-OrgID:dev" \
# --data-raw "{\"streams\": [{\"stream\": {\"job\": \"test\"}, \"values\": [[\"$(date +%s)000000000\", \"fizzbuzz\"]]}]}"


# curl -G "http://127.0.0.1:3100/loki/api/v1/query_range" \
# --data-urlencode 'query={job="test"}' \
# -H "X-Scope-OrgID:dev" | jq .data.result
