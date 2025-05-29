#!/bin/bash
# filepath: c:\gh\Pluralsight-Vault-Scripts\Access management architecture for Vault Associate 003\exercises\Vault Secrets Operator\2-install-vso.sh
# Install the Vault Operator using Helm

set -e  # Exit on any error

echo "Installing Vault Secrets Operator (VSO) using Helm..."

# Add HashiCorp Helm repository if not already added
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install VSO with explicit configuration to avoid template errors
helm install \
  --version 0.10.0 \
  --namespace vault-secrets-operator-system \
  --create-namespace \
  --set "controller.manager.clientCache.numLocks=10" \
  --set "defaultVaultConnection.enabled=true" \
  --set "defaultVaultConnection.address=http://vault.vault.svc.cluster.local:8200" \
  --set "defaultVaultConnection.skipTLSVerify=true" \
  vault-secrets-operator hashicorp/vault-secrets-operator

echo "Waiting for Vault Secrets Operator deployment to be ready..."
kubectl wait --namespace vault-secrets-operator-system --for=condition=available deployment --selector="app.kubernetes.io/name=vault-secrets-operator" --timeout=120s

echo "Vault Secrets Operator installed successfully!"

# Create a namespace for the Taco Wagon app
echo "Creating namespace 'taco-wagon'..."
kubectl create namespace taco-wagon

# Create the VaultAuth for the Taco Wagon app
kubectl apply -f "vault-auth.yaml"

# Create the Taco Wagon api secret
kubectl apply -f "static-secret.yaml"

# Check if the secret was created successfully
echo "Checking if the Taco Wagon secret was created successfully..."
kubectl get secret taco-wagon-api-keys -n taco-wagon -o yaml

# Check the values
echo "Current secret values:"
kubectl get secret taco-wagon-api-keys -n taco-wagon -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# Update the secret value in Vault
vault kv put secret/taco-wagon/api-keys stripe_key="sk_test_987654321" sendgrid_key="SG.xyz987654" google_maps_key="AIza_sample_key_123"

echo "Waiting 30 seconds for the Vault Secrets Operator to sync the updated secret..."
sleep 30

echo "Updated secret values:"
kubectl get secret taco-wagon-api-keys -n taco-wagon -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# Cleanup the kind cluster
echo "Cleaning up the kind cluster..."
kind delete cluster --name vault-demo