# Setup scaleway Transactional Email account for outgoing email
resource "scaleway_tem_domain" "main" {
  accept_tos = true
  name       = "mazenet.org"
}

resource "scaleway_iam_application" "smtp" {
  name = "smtp"
}

# Create an API key with read/write permissions
resource "scaleway_iam_api_key" "smtp_access_token" {
  description    = "API key for mazenet_volsync_backup"
  application_id = scaleway_iam_application.smtp.id
}

resource "scaleway_iam_policy" "smtp_policy" {
  name           = "smtp-email-policy"
  application_id = scaleway_iam_application.smtp.id
  rule {
    project_ids          = [var.scw_project_id]
    permission_set_names = ["TransactionalEmailEmailFullAccess"]
  }
}

# Setup the domain zone
resource "cloudflare_record" "mazenet_spf" {
  zone_id = data.cloudflare_zone.mazenet.id
  name    = "@"
  content = "\"v=spf1 ${scaleway_tem_domain.main.spf_config} mx -all\""
  type    = "TXT"
}

locals {
  dkim_content = scaleway_tem_domain.main.dkim_config
  dkim_part1 = substr(local.dkim_content, 0, 254)
  dkim_part2 = substr(local.dkim_content, 254, -1)
}

resource "cloudflare_record" "mazenet_dkim" {
  zone_id = data.cloudflare_zone.mazenet.id
  name    = "${scaleway_tem_domain.main.project_id}._domainkey"
  content = "\"${join("\" \"", regexall(".{1,255}", local.dkim_content))}\""
  type    = "TXT"
}

resource "cloudflare_record" "mazenet_dmarc" {
  zone_id = data.cloudflare_zone.mazenet.id
  name    = "_dmarc"
  content = "\"v=DMARC1; p=none; rua=mailto:postmaster@mazenet.org\""
  type    = "TXT"
}

# Setup incoming email routing with CF for incoming
resource "cloudflare_email_routing_settings" "mazenet" {
  zone_id = data.cloudflare_zone.mazenet.id
  enabled = "true"
}

# Get email address
resource "cloudflare_email_routing_address" "hca443_gmail" {
  account_id = var.cf_account_id
  email      = "hca443@gmail.com"
}

# Catch all forward
resource "cloudflare_email_routing_catch_all" "catch_all" {
  zone_id = data.cloudflare_zone.mazenet.id
  name    = "catch all forward"
  enabled = true

  matcher {
    type = "all"
  }

  action {
    type  = "forward"
    value = ["hca443@gmail.com"]
  }
}
locals {
  smtp_env = <<-EOT
    SMTP_AUTH_USER = ${scaleway_tem_domain.main.smtps_auth_user}
    SMTP_AUTH_PASS = ${scaleway_iam_api_key.smtp_access_token.secret_key}
    SMTP_PORT = ${scaleway_tem_domain.main.smtps_port}
    SMTP_HOST = ${scaleway_tem_domain.main.smtp_host}
  EOT
}

resource "local_file" "smtp_env" {
  filename = "${path.module}/output/smtp.env"
  content  = local.smtp_env
}


# Create bucket to save email
resource "scaleway_object_bucket" "mazenet_email_worker" {
  name = "mazenet-email-worker"
}

# Save the credentials (API key and secret) in Scaleway Secret Manager
resource "scaleway_secret" "email_worker_bucket_secret" {
  name = "email-worker"
  path = "/k8s/prod/app/"
  tags = ["kubernetes", "terraform"]
}

# Setup bucket policy 
resource "scaleway_iam_policy" "email_worker_policy" {
  name           = "email-worker-object-storage-policy"
  application_id = scaleway_iam_application.smtp.id
  rule {
    project_ids          = [var.scw_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageObjectsWrite", "ObjectStorageObjectsDelete"]
  }
}

resource "scaleway_object_bucket_policy" "email_worker_bucket_policy" {
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


# Activate SQS for the project
resource "scaleway_mnq_sqs" "main" {
}

resource "scaleway_mnq_sqs_credentials" "email_worker" {
  project_id = scaleway_mnq_sqs.main.project_id
  name       = "email-worker-credentials"

  permissions {
    can_manage  = true
    can_receive = true
    can_publish = true
  }
}

resource "scaleway_mnq_sqs_queue" "email_worker" {
  project_id   = scaleway_mnq_sqs.main.project_id
  name         = "email-worker"
  sqs_endpoint = scaleway_mnq_sqs.main.endpoint
  access_key   = scaleway_mnq_sqs_credentials.email_worker.access_key
  secret_key   = scaleway_mnq_sqs_credentials.email_worker.secret_key
}

locals {
  env_worker = <<-EOT
    S3_BUCKET_NAME = "${scaleway_object_bucket.mazenet_email_worker.name}"
    S3_ACCESS_KEY = "${scaleway_iam_api_key.smtp_access_token.access_key}"
    S3_SECRET_KEY = "${scaleway_iam_api_key.smtp_access_token.secret_key}"
    S3_ENDPOINT = "${scaleway_object_bucket.mazenet_email_worker.api_endpoint}"
    S3_REGION = "${scaleway_object_bucket.mazenet_email_worker.region}"
    SQS_ACCESS_KEY = "${scaleway_mnq_sqs_credentials.email_worker.access_key}"
    SQS_SECRET_KEY = "${scaleway_mnq_sqs_credentials.email_worker.secret_key}"
    SQS_ENDPOINT = "${scaleway_mnq_sqs_queue.email_worker.sqs_endpoint}"
    SQS_QUEUE_URL = "${scaleway_mnq_sqs_queue.email_worker.url}"
  EOT
}
# SQS_QUEUE_URL = "https://sqs.mnq.fr-par.scaleway.com/project-802b6dc7-d07d-45cc-be79-8822053fdf71/email-worker"
# SQS_ENDPOINT = "https://sqs.mnq.fr-par.scaleway.com"

resource "scaleway_secret_version" "email-worker" {
  secret_id = scaleway_secret.volsync_bucket_secret.id
  data = jsonencode({
    access_key = scaleway_iam_api_key.smtp_access_token.access_key
    secret_key = scaleway_iam_api_key.smtp_access_token.secret_key
  })
}

resource "local_file" "email_worker_env" {
  filename = "${path.module}/output/email-worker.env"
  content  = local.env_worker
}
