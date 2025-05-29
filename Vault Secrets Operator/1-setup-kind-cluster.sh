#!/bin/bash
# filepath: c:\gh\Pluralsight-Vault-Scripts\Access management architecture for Vault Associate 003\exercises\Vault Secrets Operator\1-setup-kind-cluster.sh
# Bash script to set up a kind cluster and install HashiCorp Vault using Helm
# Ensure you have the required tools installed:
# - kind (Kubernetes in Docker)
# - kubectl (Kubernetes command-line tool)
# - Helm (Kubernetes package manager)
# - HashiCorp Vault CLI

set -e  # Exit on any error

# Create kind cluster for Vault Secrets Operator demo
echo "Creating kind cluster for Vault demo..."

# Create kind cluster configuration with port mappings for Vault
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 8200
    hostPort: 8200
    protocol: TCP
  - containerPort: 30820
    hostPort: 30820
    protocol: TCP
EOF

# Create the kind cluster
kind create cluster --name vault-demo --config kind-config.yaml

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "Kind cluster created successfully!"

# Install HashiCorp Vault using Helm
echo "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

echo "Creating namespace 'vault'..."
kubectl create namespace vault

echo "Installing Vault in dev mode with root token 'root'..."
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "ui.enabled=true" \
  --set "ui.serviceType=NodePort" \
  --set "server.service.type=NodePort" \
  --set "server.service.nodePort=30820" \
  --set "server.injector.enabled=false"

echo "Waiting for Vault pod to be ready..."
kubectl wait --namespace vault --for=condition=Ready pod --selector="app.kubernetes.io/name=vault" --timeout=120s

echo "Vault is now running in dev mode in the 'vault' namespace!"
echo "Root token: root"
echo "Vault UI accessible at: http://localhost:30820"
echo "To access Vault CLI: kubectl exec -it vault-0 -n vault -- vault status"

# Set VAULT_ADDR environment variable for Vault CLI
export VAULT_ADDR="http://localhost:30820"
export VAULT_TOKEN="root"
vault status

# Set up the Kubernetes auth method in Vault
echo "Setting up Kubernetes auth method in Vault..."
vault auth enable kubernetes

# Configure the Kubernetes auth method
# Get the KUBERNETES_PORT_443_TCP_ADDR environment variable from the Vault pod
KUBERNETES_PORT_443_TCP_ADDR=$(kubectl exec -n vault vault-0 -- printenv KUBERNETES_PORT_443_TCP_ADDR)
vault write auth/kubernetes/config kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443"

# Create some sample secrets in Vault
echo "Creating sample secrets in Vault..."

# Create three secrets at the path secret/taco-wagon using local Vault CLI
echo "Creating secret 1: Database credentials..."
vault kv put secret/taco-wagon/database username="db_admin" password="super_secret_db_pass" host="taco-db.example.com" port="5432"

echo "Creating secret 2: API keys..."
vault kv put secret/taco-wagon/api-keys stripe_key="sk_test_123456789" sendgrid_key="SG.abc123def456" google_maps_key="AIza_sample_key_789"

echo "Creating secret 3: Service configuration..."
vault kv put secret/taco-wagon/config app_env="production" debug_mode="false" max_orders="100" notification_email="admin@taco-wagon.com"

# Create a policy for the Taco Wagon app
echo "Creating policy for Taco Wagon app..."
cat > taco-wagon-policy.hcl << EOF
path "secret/data/taco-wagon/*" {
  capabilities = ["read","list"]
}

path "secret/metadata/taco-wagon/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write taco-wagon-policy taco-wagon-policy.hcl

# Create a role called vso in Vault that allows the Vault Secrets Operator to authenticate
echo "Creating Kubernetes auth role for Taco Wagon app..."
vault write auth/kubernetes/role/taco-wagon \
  bound_service_account_names=taco-wagon-app \
  bound_service_account_namespaces=taco-wagon \
  policies=taco-wagon-policy \
  ttl=24h

# Clean up temporary files
rm -f taco-wagon-policy.hcl
rm -f kind-config.yaml

echo "Kubernetes auth method configured successfully!"
