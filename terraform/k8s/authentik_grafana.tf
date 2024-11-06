resource "random_string" "grafana_prod_client_id" {
  length  = 40
  special = false
}

resource "authentik_provider_oauth2" "grafana_prod" {
  name                   = "grafana-prod"
  client_id              = resource.random_string.grafana_prod_client_id.result
  authorization_flow     = data.authentik_flow.default-authorization-flow.id
  invalidation_flow      = data.authentik_flow.default-invalidation-flow.id
  redirect_uris          = ["https://grafana.int.mazenet.org/login/generic_oauth"]
  refresh_token_validity = "hours=24"
  signing_key            = data.authentik_certificate_key_pair.generated.id
  property_mappings      = data.authentik_property_mapping_provider_scope.oauth2_basic_scope.ids
}

resource "authentik_application" "grafana_prod" {
  name              = "grafana-prod"
  slug              = "grafana-prod"
  protocol_provider = authentik_provider_oauth2.grafana_prod.id
}

resource "scaleway_secret" "grafana_prod" {
  name = "grafana-oidc"
  path = "/k8s/prod/apps/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_secret_version" "grafana_prod" {
  secret_id = scaleway_secret.grafana_prod.id
  data = jsonencode({
    OAUTH_ID        = authentik_provider_oauth2.grafana_prod.client_id
    OAUTH_SECRET    = authentik_provider_oauth2.grafana_prod.client_secret
    OAUTH_WELLKNOWN = "https://auth.mazenet.org/application/o/${resource.authentik_application.grafana_prod.slug}/.well-known/openid-configuration"
  })
}

locals {
  grafana_env = <<-EOT
    OAUTH_ID     = ${authentik_provider_oauth2.grafana_prod.client_id}
    OAUTH_SECRET = ${authentik_provider_oauth2.grafana_prod.client_secret}
    OAUTH_WELLKNOWN = https://auth.mazenet.org/application/o/${resource.authentik_application.grafana_prod.slug}/.well-known/openid-configuration
  EOT
}

resource "local_file" "grafana_env" {
  filename = "${path.module}/output/grafana.env"
  content  = local.grafana_env
}
