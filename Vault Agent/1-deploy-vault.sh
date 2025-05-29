#!/bin/bash

# This script starts a basic Vault server in dev mode, creates a secret, configures the AppRole auth method,
# and creates a policy with read-only access to the secret.

# Start Vault server in dev mode in the background
echo "Starting Vault server in dev mode..."
vault server -dev -dev-root-token-id=root &
VAULT_PID=$!

# Set environment variable to point to the Vault server
export VAULT_ADDR="http://127.0.0.1:8200"

# Wait for Vault to start
echo "Waiting for Vault to start..."
sleep 2

# The dev server automatically sets the root token to "root"
export VAULT_TOKEN="root"

# Create the "tacos" secret in the KV secrets engine
echo "Creating 'tacos' secret..."
vault kv put secret/tacos filling="carnitas" salsa="verde" tortilla="corn"

# Mount the AppRole auth method
echo "Enabling AppRole auth method..."
vault auth enable approle

# Create the web-server-ro policy
echo "Creating web-server-ro policy..."
cat > web-server-ro.hcl << 'EOF'
# Read-only access to 'tacos' secret
path "secret/data/tacos" {
  capabilities = ["read"]
}
EOF

# Apply the policy to Vault
vault policy write web-server-ro web-server-ro.hcl

# Remove the temporary policy file
rm -f web-server-ro.hcl

# Configure a role named "web-server" with the web-server-ro policy
echo "Creating web-server role with web-server-ro policy..."
vault write auth/approle/role/web-server policies="web-server-ro"

# Display information about how to access the Vault server
echo ""
echo "Vault server is running in dev mode at $VAULT_ADDR"
echo "Root token: $VAULT_TOKEN"
echo "AppRole 'web-server' has been configured with 'web-server-ro' policy"
echo "To get the RoleID and SecretID for the web-server role, run:"
echo "  vault read auth/approle/role/web-server/role-id"
echo "  vault write -f auth/approle/role/web-server/secret-id"
echo ""
echo "Vault server is running in the background (PID: $VAULT_PID)"
echo "To stop the server, run: kill $VAULT_PID"
