resource "auth0_client" "grafana" {
  name            = "grafana"
  app_type        = "regular_web"
  callbacks       = var.grafana_callback_urls
  oidc_conformant = true
}

resource "auth0_client_credentials" "grafana" {
  client_id             = auth0_client.grafana.id
  authentication_method = "client_secret_post"
}

resource "scaleway_secret" "grafana_oidc" {
  name = "grafana-oidc"
  path = "/k8s/${var.env}/apps/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_secret_version" "grafana_oidc" {
  secret_id = scaleway_secret.grafana_oidc.id
  data = jsonencode({
    OAUTH_ID        = auth0_client_credentials.grafana.client_id
    OAUTH_SECRET    = auth0_client_credentials.grafana.client_secret
    OAUTH_WELLKNOWN = "https://${var.auth0_domain}/.well-known/openid-configuration"
  })
}

locals {
  grafana_env = <<-EOT
    OAUTH_ID     = ${auth0_client_credentials.grafana.client_id}
    OAUTH_SECRET = ${auth0_client_credentials.grafana.client_secret}
    OAUTH_WELLKNOWN = https://${var.auth0_domain}/.well-known/openid-configuration
  EOT
}

resource "local_file" "grafana_env" {
  filename = "${path.module}/output/grafana.env"
  content  = local.grafana_env
}
