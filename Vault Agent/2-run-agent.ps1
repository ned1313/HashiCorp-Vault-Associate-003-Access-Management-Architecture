# Start by setting environment variables for the Vault server and token
$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:VAULT_TOKEN = "root"

# Create the role ID and secret ID for the AppRole
vault read -field=role_id auth/approle/role/web-server/role-id > role-id
vault write -f -field=secret_id auth/approle/role/web-server/secret-id > secret-id

# Unset the environment variables
$env:VAULT_ADDR = $null
$env:VAULT_TOKEN = $null

# Start the Vault Agent using the configuration file
vault agent -config="config/agent-file-template.hcl"

# Check that the file was created
# Stop the agent with Ctrl+C

# Adjust the template for Bash or PowerShell
# Now run the agent for environment variables
vault agent -config="config/agent-env-template-pwsh.hcl"

# Stop the dev server
Stop-Process -Name "vault"

# Clean up files
Remove-Item -Path "role-id" -Force
Remove-Item -Path "secret-id" -Force
Remove-Item -Path "agent-token" -Force
Remove-Item -Path "recipe.json" -Force