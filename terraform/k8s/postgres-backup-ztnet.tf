resource "scaleway_iam_application" "cnpg" {
  name = "cnpg"
}

# Create Scaleway bucket
resource "scaleway_object_bucket" "mazenet_cnpg_backup" {
  name = "mazenet-cnpg-backup"
}

# Create an API key with read/write permissions
resource "scaleway_iam_api_key" "bucket_cnpg_access_key" {
  description    = "API key for cnpg backup"
  application_id = scaleway_iam_application.cnpg.id
}

# Save the credentials (API key and secret) in Scaleway Secret Manager
resource "scaleway_secret" "cnpg_bucket_secret" {
  name = "cnpg-backup"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}


resource "scaleway_iam_policy" "cnpg_policy" {
  name           = "cnpg-object-storage-policy"
  application_id = scaleway_iam_application.cnpg.id
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

resource "scaleway_object_bucket_policy" "cnpg_bucket_policy" {
  bucket = scaleway_object_bucket.mazenet_cnpg_backup.id
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
            "${scaleway_object_bucket.mazenet_cnpg_backup.name}",
            "${scaleway_object_bucket.mazenet_cnpg_backup.name}/*"
          ]
        },
        {
          Sid    = "Allow application cnpg read/write access",
          Effect = "Allow",
          Principal = {
            SCW = "application_id:${scaleway_iam_application.cnpg.id}"
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
            "${scaleway_object_bucket.mazenet_cnpg_backup.name}",
            "${scaleway_object_bucket.mazenet_cnpg_backup.name}/*"
          ]
        }
      ]
    }
  )
}

resource "scaleway_secret_version" "cnpg" {
  secret_id = scaleway_secret.cnpg_bucket_secret.id
  data = jsonencode({
    ACCESS_KEY_ID     = scaleway_iam_api_key.bucket_cnpg_access_key.access_key
    ACCESS_SECRET_KEY = scaleway_iam_api_key.bucket_cnpg_access_key.secret_key
  })
}

