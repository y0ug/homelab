resource "scaleway_iam_application" "volsync" {
  name = "volsync"
}

# Create Scaleway bucket
resource "scaleway_object_bucket" "mazenet_volsync_backup" {
  name = "mazenet-volsync-backup-4"
}

# Create an API key with read/write permissions
resource "scaleway_iam_api_key" "bucket_access_key" {
  description    = "API key for mazenet_volsync_backup"
  application_id = scaleway_iam_application.volsync.id
}

# Save the credentials (API key and secret) in Scaleway Secret Manager
resource "scaleway_secret" "volsync_bucket_secret" {
  name = "volsync-rclone"
  path = "/k8s/prod/core/"
  tags = ["kubernetes", "terraform"]
}


resource "scaleway_iam_policy" "volsync_policy" {
  name           = "volsync-object-storage-policy"
  application_id = scaleway_iam_application.volsync.id
  rule {
    project_ids          = [var.scw_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageObjectsWrite", "ObjectStorageObjectsDelete"]
  }
}

resource "scaleway_object_bucket_policy" "volsync_bucket_policy" {
  bucket = scaleway_object_bucket.mazenet_volsync_backup.id
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
            "${scaleway_object_bucket.mazenet_volsync_backup.name}",
            "${scaleway_object_bucket.mazenet_volsync_backup.name}/*"
          ]
        },
        {
          Sid    = "Allow application volsync read/write access",
          Effect = "Allow",
          Principal = {
            SCW = "application_id:${scaleway_iam_application.volsync.id}"
          },
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            "${scaleway_object_bucket.mazenet_volsync_backup.name}",
            "${scaleway_object_bucket.mazenet_volsync_backup.name}/*"
          ]
        }
      ]
    }
  )
}

locals {
  rclone_config_data = <<-EOT
    [rclone-bucket]
    type = s3
    provider = Scaleway 
    env_auth = false
    access_key_id = ${scaleway_iam_api_key.bucket_access_key.access_key}
    secret_access_key = ${scaleway_iam_api_key.bucket_access_key.secret_key}
    region = fr-par 
    endpoint = s3.fr-par.scw.cloud 
    acl = private
    storage_class = STANDARD
  EOT
}

resource "scaleway_secret_version" "volsync" {
  secret_id = scaleway_secret.volsync_bucket_secret.id
  data = jsonencode({
    access_key    = scaleway_iam_api_key.bucket_access_key.access_key
    secret_key    = scaleway_iam_api_key.bucket_access_key.secret_key
    "rclone.conf" = local.rclone_config_data
  })
}

resource "local_file" "rclone_config" {
  filename = "${path.module}/output/volsync_rclone.conf"
  content  = local.rclone_config_data
}
