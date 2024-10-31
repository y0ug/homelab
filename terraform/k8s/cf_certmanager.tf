data "cloudflare_api_token_permission_groups" "all" {}

data "cloudflare_zone" "mazenet" {
  # filter = { name = "mazenet.org" }
  name = "mazenet.org"
}

resource "cloudflare_api_token" "cert_manager" {
  name = "k8s_cert_manager"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.mazenet.id}" = "*"
    }
  }
}

resource "scaleway_secret" "cert_manager" {
  name = "cert-manager-cf"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}


resource "scaleway_secret_version" "cert_manager_prod" {
  secret_id = scaleway_secret.cert_manager.id
  data = jsonencode({
    apikey = cloudflare_api_token.cert_manager.value
  })
}
