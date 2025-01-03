terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2024.10.0"
    }
    scaleway = {
      source  = "scaleway/scaleway"
      version = "2.47.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.44.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }

  backend "s3" {
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    bucket                      = "mazenet-opentofu"
    key                         = "test.tfstate"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}

provider "authentik" {
}

provider "cloudflare" {
}

provider "scaleway" {
  region = "fr-par"
  zone   = "fr-par-1"
}

