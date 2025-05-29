#!/bin/bash

# Start by setting environment variables for the Vault server and token
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Create the role ID and secret ID for the AppRole
vault read -field=role_id auth/approle/role/web-server/role-id > role-id
vault write -f -field=secret_id auth/approle/role/web-server/secret-id > secret-id

# Unset the environment variables
unset VAULT_ADDR
unset VAULT_TOKEN

# Start the Vault Agent using the configuration file
vault agent -config="config/agent-file-template.hcl"

# Check that the file was created
# Stop the agent with Ctrl+C

# Adjust the template for Bash or PowerShell
# Now run the agent for environment variables
vault agent -config="config/agent-env-template-bash.hcl"

# Stop the dev server
pkill -f "vault server"

# Clean up files
rm -f role-id
rm -f secret-id
rm -f agent-token
rm -f recipe.json