data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "oauth2_basic_scope" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

resource "authentik_provider_oauth2" "oauth2_proxy_prod" {
  name                   = "oauth2-proxy-prod"
  client_id              = "oauth2-proxy-prod"
  authorization_flow     = data.authentik_flow.default-authorization-flow.id
  redirect_uris          = ["https://sso.k8s.int.mazenet.org/oauth2/callback"]
  refresh_token_validity = "hours=24"
  signing_key            = data.authentik_certificate_key_pair.generated.id
  property_mappings      = data.authentik_property_mapping_provider_scope.oauth2_basic_scope.ids
}

resource "authentik_application" "oauth2_proxy_prod" {
  name              = "oauth2-proxy-prod"
  slug              = "oauth2-proxy-prod"
  protocol_provider = authentik_provider_oauth2.oauth2_proxy_prod.id
}

resource "scaleway_secret" "oauth2_proxy_prod" {
  name = "oauth2-proxy"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_secret_version" "oauth2_proxy_prod" {
  secret_id = scaleway_secret.oauth2_proxy_prod.id
  data = jsonencode({
    client_secret = authentik_provider_oauth2.oauth2_proxy_prod.client_secret
    client_id     = authentik_provider_oauth2.oauth2_proxy_prod.client_id
    cookie_secret = var.oauth2_proxy_cookie_secret
  })
}
