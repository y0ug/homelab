resource "auth0_client" "oauth2_proxy" {
  name            = "oauth2-proxy"
  callbacks       = var.oauth2_proxy_callback_urls
  oidc_conformant = true
  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_client_credentials" "oauth2_proxy" {
  client_id             = auth0_client.grafana.id
  authentication_method = "client_secret_post"
}

resource "scaleway_secret" "oauth2_proxy_oidc" {
  name = "oauth2-proxy-oidc"
  path = "/k8s/${var.env}/core/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_secret_version" "oauth2_proxy_prod" {
  secret_id = scaleway_secret.oauth2_proxy_oidc.id
  data = jsonencode({
    client_secret = auth0_client_credentials.oauth2_proxy.client_secret
    client_id     = auth0_client_credentials.oauth2_proxy.client_id
    cookie_secret = var.oauth2_proxy_cookie_secret
  })
}
