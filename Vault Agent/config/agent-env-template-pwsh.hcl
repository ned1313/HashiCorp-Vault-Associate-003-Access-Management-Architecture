vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "role-id"
      secret_id_file_path = "secret-id"
      remove_secret_id_file_after_reading = false
    }
  }
  sink {
    type = "file"
    config = {
      path = "agent-token"
    }
  }
}

env_template "SECRET_RECIPE" {
  contents = <<EOT
  {{ with secret "secret/tacos" }} 
  {{ .Data.data }}
  {{ end }}
  EOT
}

exec {
  command = ["pwsh", "-c", "echo $env:SECRET_RECIPE"]
  restart_on_secret_changes = "always"
}
