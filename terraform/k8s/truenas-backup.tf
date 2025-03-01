resource "scaleway_iam_application" "truenasbk" {
  name = "truenasbk"
}

# Create Scaleway bucket
resource "scaleway_object_bucket" "mazenet_truenasbk" {
  name = "mazenet-truenasbk"
  versioning {
    enabled = true
  }
}

# Create an API key with read/write permissions
resource "scaleway_iam_api_key" "bucket_truenasbk_access_key" {
  description    = "API key for truenasbk"
  application_id = scaleway_iam_application.truenasbk.id
}

# Save the credentials (API key and secret) in Scaleway Secret Manager
resource "scaleway_secret" "truenasbk_bucket_secret" {
  name = "truenasbk-s3"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}


resource "scaleway_iam_policy" "truenasbk_policy" {
  name           = "truenasbk-object-storage-policy"
  application_id = scaleway_iam_application.truenasbk.id
  rule {
    project_ids = [var.scw_project_id]
    permission_set_names = [
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
      "ObjectStorageBucketsRead" # Required for HeadBucket
    ]
  }
}

resource "scaleway_object_bucket_policy" "truenasbk_bucket_policy" {
  bucket = scaleway_object_bucket.mazenet_truenasbk.id
  policy = jsonencode(
    {
      Id      = "policy"
      Version = "2023-04-17",
      Statement = [
        {
          Sid    = "Allow admin access",
          Effect = "Allow",
          Principal = {
            SCW = "user_id:bfccf1f7-b546-4c59-b9da-6b60337f3084"
          },
          Action = [
            "*",
          ]
          Resource = [
            "${scaleway_object_bucket.mazenet_truenasbk.name}",
            "${scaleway_object_bucket.mazenet_truenasbk.name}/*"
          ]
        },
        {
          Sid    = "Allow application truenasbk read/write access",
          Effect = "Allow",
          Principal = {
            SCW = "application_id:${scaleway_iam_application.truenasbk.id}"
          },
          # Action = [
          #   "s3:*",
          # ]
          # Need HeadBucket but this is not available
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            #"s3:HeadBucket"
          ]
          Resource = [
            "${scaleway_object_bucket.mazenet_truenasbk.name}",
            "${scaleway_object_bucket.mazenet_truenasbk.name}/*"
          ]
        }
      ]
    }
  )
}

resource "scaleway_secret_version" "truenasbk" {
  secret_id = scaleway_secret.truenasbk_bucket_secret.id
  data = jsonencode({
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.bucket_truenasbk_access_key.access_key
    AWS_ACCESS_SECRET_KEY = scaleway_iam_api_key.bucket_truenasbk_access_key.secret_key
  })
}

resource "local_file" "truenasbk" {
  filename = "${path.module}/output/volsync_rclone.conf"
  content  = local.rclone_config_data
}
