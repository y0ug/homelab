resource "scaleway_iam_application" "container_registry" {
  name = "container_registry"
}

resource "scaleway_registry_namespace" "mazenet" {
  name        = "mazenet-cr"
  description = "homelab mazenet contrainer container_registry"
  is_public   = false
}

# Create an API key with read/write permissions
resource "scaleway_iam_api_key" "cr_mazenet" {
  description    = "API key for accessing the private container_registry"
  application_id = scaleway_iam_application.container_registry.id
}

# Save the credentials (API key and secret) in Scaleway Secret Manager
resource "scaleway_secret" "container_registry_secret" {
  name = "cr-scw"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}


resource "scaleway_iam_policy" "container_registry_policy" {
  name           = "container_registry-object-storage-policy"
  application_id = scaleway_iam_application.container_registry.id
  rule {
    project_ids          = [var.scw_project_id]
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

locals {
  endpoint    = "rg.fr-par.scw.cloud"
  cr_env      = <<-EOT
     ACCESS_KEY=${scaleway_iam_api_key.cr_mazenet.access_key}
     SECRET_KEY=${scaleway_iam_api_key.cr_mazenet.secret_key}
   EOT
  docker_auth = base64encode("nologin:${scaleway_iam_api_key.cr_mazenet.secret_key}")
  docker_config_json = jsonencode({
    auths = {
      #(scaleway_registry_namespace.mazenet.endpoint) = {
      (local.endpoint) = {
        auth = local.docker_auth
      }
    }
  })
}

resource "scaleway_secret_version" "container_registry" {
  secret_id = scaleway_secret.container_registry_secret.id
  data = jsonencode({
    docker-server   = scaleway_registry_namespace.mazenet.endpoint
    docker-username = "nologin"
    docker-password = scaleway_iam_api_key.cr_mazenet.secret_key
    docker-email    = ""
    # ".dockerconfigjson" = local.docker_config_json
  })
}

resource "local_file" "cr_envfile" {
  filename = "${path.module}/output/cr.env"
  content  = local.cr_env
}
