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

template {
  source = "config/recipe-to-file.ctmpl"
  destination = "recipe.json"
}
