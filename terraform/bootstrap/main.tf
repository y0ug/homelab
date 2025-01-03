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
}

provider "authentik" {
}

provider "cloudflare" {
}

provider "scaleway" {
  project_id = "802b6dc7-d07d-45cc-be79-8822053fdf71"
  region     = "fr-par"
}

resource "scaleway_iam_application" "opentofu" {
  name = "opentofu"
}

# Create Scaleway bucket with versioning
resource "scaleway_object_bucket" "mazenet_opentofu" {
  name = "mazenet-opentofu"
  versioning {
    enabled = true
  }
}

resource "scaleway_iam_api_key" "bucket_opentofu_access_key" {
  description    = "API key for opentofu"
  application_id = scaleway_iam_application.opentofu.id
}

resource "scaleway_secret" "opentofu_bucket_secret" {
  name = "opentofu-s3"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}

resource "scaleway_iam_policy" "opentofu_policy" {
  name           = "opentofu-object-storage-policy"
  application_id = scaleway_iam_application.opentofu.id

  rule {
    project_ids = ["802b6dc7-d07d-45cc-be79-8822053fdf71"]
    permission_set_names = [
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
      "ObjectStorageBucketsRead"
    ]
  }
}

resource "scaleway_object_bucket_policy" "opentofu_bucket_policy" {
  bucket = scaleway_object_bucket.mazenet_opentofu.id
  policy = jsonencode({
    Id      = "policy"
    Version = "2023-04-17"
    Statement = [
      # Example statement: admin-level access
      {
        Sid    = "Allow admin access"
        Effect = "Allow"
        Principal = {
          SCW = "user_id:bfccf1f7-b546-4c59-b9da-6b60337f3084"
        }
        Action = [
          "*",
        ]
        Resource = [
          "${scaleway_object_bucket.mazenet_opentofu.name}",
          "${scaleway_object_bucket.mazenet_opentofu.name}/*"
        ]
      },
      # Example statement: opentofu read/write access
      {
        Sid    = "Allow application opentofu read/write access"
        Effect = "Allow"
        Principal = {
          SCW = "application_id:${scaleway_iam_application.opentofu.id}"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
          # "s3:HeadBucket" (not currently supported on Scaleway)
        ]
        Resource = [
          "${scaleway_object_bucket.mazenet_opentofu.name}",
          "${scaleway_object_bucket.mazenet_opentofu.name}/*"
        ]
      }
    ]
  })
}

locals {
  opentofu_config = {
    AWS_REGION            = scaleway_object_bucket.mazenet_opentofu.region
    AWS_DEFAULT_REGION    = scaleway_object_bucket.mazenet_opentofu.region
    AWS_ENDPOINT_URL_S3   = "https://s3.${scaleway_object_bucket.mazenet_opentofu.region}.scw.cloud"
    AWS_S3_ENDPOINT       = "https://s3.${scaleway_object_bucket.mazenet_opentofu.region}.scw.cloud"
    BUCKET_NAME           = scaleway_object_bucket.mazenet_opentofu.name
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.bucket_opentofu_access_key.access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.bucket_opentofu_access_key.secret_key
  }
}
resource "scaleway_secret_version" "opentofu" {
  secret_id = scaleway_secret.opentofu_bucket_secret.id
  data      = jsonencode(local.opentofu_config)
}

resource "local_file" "opentofu_yaml" {
  filename = "${path.module}/output/opentofu.yaml"
  content  = yamlencode(local.opentofu_config)
}

resource "local_file" "opentofu_env" {
  filename = "${path.module}/output/opentofu.env"
  content  = join("\n", [for k, v in local.opentofu_config : "${k}=${v}"])
}
