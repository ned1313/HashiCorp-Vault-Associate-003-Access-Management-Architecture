# This script starts a basic Vault server in dev mode, creates a secret, configures the AppRole auth method,
# and creates a policy with read-only access to the secret.

# Start Vault server in dev mode in the background
Write-Host "Starting Vault server in dev mode..."
$process = Start-Process -FilePath "vault" -ArgumentList "server", "-dev", "-dev-root-token-id=root" -PassThru -WindowStyle Hidden

# Set environment variable to point to the Vault server
$env:VAULT_ADDR = "http://127.0.0.1:8200"

# Wait for Vault to start
Write-Host "Waiting for Vault to start..."
Start-Sleep -Seconds 2

# The dev server automatically sets the root token to "root"
$env:VAULT_TOKEN = "root"

# Create the "tacos" secret in the KV secrets engine
Write-Host "Creating 'tacos' secret..."
vault kv put secret/tacos filling="carnitas" salsa="verde" tortilla="corn"

# Mount the AppRole auth method
Write-Host "Enabling AppRole auth method..."
vault auth enable approle

# Create the web-server-ro policy
Write-Host "Creating web-server-ro policy..."
@"
# Read-only access to 'tacos' secret
path "secret/data/tacos" {
  capabilities = ["read"]
}
"@ | Out-File -FilePath "web-server-ro.hcl" -Encoding ASCII

# Apply the policy to Vault
vault policy write web-server-ro web-server-ro.hcl

# Remove the temporary policy file
Remove-Item web-server-ro.hcl -Force

# Configure a role named "web-server" with the web-server-ro policy
Write-Host "Creating web-server role with web-server-ro policy..."
vault write auth/approle/role/web-server policies="web-server-ro"

# Display information about how to access the Vault server
Write-Host "`nVault server is running in dev mode at $env:VAULT_ADDR"
Write-Host "Root token: $env:VAULT_TOKEN"
Write-Host "AppRole 'web-server' has been configured with 'web-server-ro' policy"
Write-Host "To get the RoleID and SecretID for the web-server role, run:"
Write-Host "  vault read auth/approle/role/web-server/role-id"
Write-Host "  vault write -f auth/approle/role/web-server/secret-id"
