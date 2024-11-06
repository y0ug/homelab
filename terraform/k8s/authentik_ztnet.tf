resource "random_string" "ztnet_prod_client_id" {
  length  = 40
  special = false
}

resource "authentik_provider_oauth2" "ztnet_prod" {
  name                   = "ztnet-prod"
  client_id              = resource.random_string.ztnet_prod_client_id.result
  authorization_flow     = data.authentik_flow.default-authorization-flow.id
  invalidation_flow      = data.authentik_flow.default-invalidation-flow.id
  redirect_uris          = ["https://ztnet.int.mazenet.org/api/auth/callback/oauth"]
  refresh_token_validity = "hours=24"
  signing_key            = data.authentik_certificate_key_pair.generated.id
  property_mappings      = data.authentik_property_mapping_provider_scope.oauth2_basic_scope.ids
}

resource "authentik_application" "ztnet_prod" {
  name              = "ztnet-prod"
  slug              = "ztnet-prod"
  protocol_provider = authentik_provider_oauth2.ztnet_prod.id
}

resource "scaleway_secret" "ztnet_prod" {
  name = "ztnet"
  path = "/k8s/prod/apps/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_secret_version" "ztnet_prod" {
  secret_id = scaleway_secret.ztnet_prod.id
  data = jsonencode({
    OAUTH_ID     = authentik_provider_oauth2.ztnet_prod.client_id
    OAUTH_SECRET = authentik_provider_oauth2.ztnet_prod.client_secret
    # @TODO set slug from 
    OAUTH_WELLKNOWN = "https://auth.mazenet.org/application/o/${resource.authentik_application.ztnet_prod.slug}/.well-known/openid-configuration"
  })
}

locals {
  ztnet_env = <<-EOT
    OAUTH_ID     = ${authentik_provider_oauth2.ztnet_prod.client_id}
    OAUTH_SECRET = ${authentik_provider_oauth2.ztnet_prod.client_secret}
    OAUTH_WELLKNOWN = https://auth.mazenet.org/application/o/${resource.authentik_application.ztnet_prod.slug}/.well-known/openid-configuration
  EOT
}

resource "local_file" "ztnet_env" {
  filename = "${path.module}/output/ztnet.env"
  content  = local.ztnet_env
}
