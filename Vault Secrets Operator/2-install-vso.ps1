# Install the Vault Operator using Helm
Write-Host "Installing Vault Secrets Operator (VSO) using Helm..."

# Add HashiCorp Helm repository if not already added
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install VSO with explicit configuration to avoid template errors
helm install `
  --version 0.10.0 `
  --namespace vault-secrets-operator-system `
  --create-namespace `
  --set "controller.manager.clientCache.numLocks=10" `
  --set "defaultVaultConnection.enabled=true" `
  --set "defaultVaultConnection.address=http://vault.vault.svc.cluster.local:8200" `
  --set "defaultVaultConnection.skipTLSVerify=true" `
  vault-secrets-operator hashicorp/vault-secrets-operator

Write-Host "Waiting for Vault Secrets Operator deployment to be ready..."
kubectl wait --namespace vault-secrets-operator-system --for=condition=available deployment --selector="app.kubernetes.io/name=vault-secrets-operator" --timeout=120s

Write-Host "Vault Secrets Operator installed successfully!"

# Create a namespace for the Taco Wagon app
Write-Host "Creating namespace 'taco-wagon'..."
kubectl create namespace taco-wagon

# Create the VaultAuth for the Taco Wagon app
kubectl apply -f "vault-auth.yaml"

# Create the Taco Wagon api secret
kubectl apply -f "static-secret.yaml"

# Check if the secret was created successfully
Write-Host "Checking if the Taco Wagon secret was created successfully..."
kubectl get secret taco-wagon-api-keys -n taco-wagon -o yaml

# Check the values
kubectl get secret taco-wagon-api-keys -n taco-wagon -o json | ConvertFrom-Json | % { $_.data.PSObject.Properties | % { "$($_.Name): $( [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.Value)) )" } }

# Update the secret value in Vault
vault kv put secret/taco-wagon/api-keys stripe_key="sk_test_987654321" sendgrid_key="SG.xyz987654" google_maps_key="AIza_sample_key_123"

# Wait about 30 seconds for the Vault Secrets Operator to sync the updated
kubectl get secret taco-wagon-api-keys -n taco-wagon -o json | ConvertFrom-Json | % { $_.data.PSObject.Properties | % { "$($_.Name): $( [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.Value)) )" } }

# Clean up the kind cluster after the demo
Write-Host "Cleaning up the kind cluster..."
kind delete cluster --name vault-demo

