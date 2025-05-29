# PowerShell script to set up a kind cluster and install HashiCorp Vault using Helm
# Ensure you have the required tools installed:
# - kind (Kubernetes in Docker)
# - kubectl (Kubernetes command-line tool)
# - Helm (Kubernetes package manager)
# - HashiCorp Vault CLI

# Create kind cluster for Vault Secrets Operator demo
Write-Host "Creating kind cluster for Vault demo..."

# Create kind cluster configuration with port mappings for Vault
$kindConfig = @"
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
"@

# Write the kind configuration to a file
$kindConfig | Out-File -FilePath "kind-config.yaml" -Encoding utf8

# Create the kind cluster
kind create cluster --name vault-demo --config kind-config.yaml

Write-Host "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

Write-Host "Kind cluster created successfully!"

# Install HashiCorp Vault using Helm
Write-Host "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

Write-Host "Creating namespace 'Vault'..."
kubectl create namespace vault

Write-Host "Installing Vault in dev mode with root token 'root'..."
helm install vault hashicorp/vault `
  --namespace vault `
  --set "server.dev.enabled=true" `
  --set "server.dev.devRootToken=root" `
  --set "ui.enabled=true" `
  --set "ui.serviceType=NodePort" `
  --set "server.service.type=NodePort" `
  --set "server.service.nodePort=30820" `
  --set "server.injector.enabled=false" 

Write-Host "Waiting for Vault pod to be ready..."
kubectl wait --namespace vault --for=condition=Ready pod --selector="app.kubernetes.io/name=vault" --timeout=120s

Write-Host "Vault is now running in dev mode in the 'vault' namespace!"
Write-Host "Root token: root"
Write-Host "Vault UI accessible at: http://localhost:30820"
Write-Host "To access Vault CLI: kubectl exec -it vault-0 -n Vault -- vault status"

# Set VAULT_ADDR environment variable for Vault CLI
$env:VAULT_ADDR = "http://localhost:30820"
$env:VAULT_TOKEN = "root"
vault status

# Set up the Kubernetes auth method in Vault
Write-Host "Setting up Kubernetes auth method in Vault..."
vault auth enable kubernetes

# Configure the Kubernetes auth method
# Get the KUBERNETES_PORT_443_TCP_ADDR environment variable from the Vault pod
$KUBERNETES_PORT_443_TCP_ADDR = kubectl exec -n vault vault-0 -- printenv KUBERNETES_PORT_443_TCP_ADDR
vault write auth/kubernetes/config kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443"

# Create some sample secrets in Vault
Write-Host "Creating sample secrets in Vault..."

# Create three secrets at the path secret/taco-wagon using local Vault CLI
Write-Host "Creating secret 1: Database credentials..."
vault kv put secret/taco-wagon/database username="db_admin" password="super_secret_db_pass" host="taco-db.example.com" port="5432"

Write-Host "Creating secret 2: API keys..."
vault kv put secret/taco-wagon/api-keys stripe_key="sk_test_123456789" sendgrid_key="SG.abc123def456" google_maps_key="AIza_sample_key_789"

Write-Host "Creating secret 3: Service configuration..."
vault kv put secret/taco-wagon/config app_env="production" debug_mode="false" max_orders="100" notification_email="admin@taco-wagon.com"

# Create a policy for the Taco Wagon app
Write-Host "Creating policy for Taco Wagon app..."
$taco_wagon_policy = @"
path "secret/data/taco-wagon/*" {
  capabilities = ["read","list"]
}

path "secret/metadata/taco-wagon/*" {
  capabilities = ["read", "list"]
}
"@

$taco_wagon_policy | Out-File -FilePath "taco-wagon-policy.hcl" -Encoding utf8
vault policy write taco-wagon-policy taco-wagon-policy.hcl

# Create a role called vso in Vault that allows the Vault Secrets Operator to authenticate
Write-Host "Creating Kubernetes auth role for Taco Wagon app..."
vault write auth/kubernetes/role/taco-wagon `
  bound_service_account_names=taco-wagon-app `
  bound_service_account_namespaces=taco-wagon `
  policies=taco-wagon-policy `
  ttl=24h

# Clean up temporary files
Remove-Item "taco-wagon-policy.hcl" -ErrorAction SilentlyContinue
Remove-Item "kind-config.yaml" -ErrorAction SilentlyContinue

Write-Host "Kubernetes auth method configured successfully!"


