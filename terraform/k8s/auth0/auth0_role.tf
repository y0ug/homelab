resource "auth0_role" "users" {
  name        = "users"
  description = "Basic users group"
}

resource "auth0_role" "media_viewers" {
  name        = "media-viewers"
  description = "Users who can view media"
}

resource "auth0_role" "media_admins" {
  name        = "media-admins"
  description = "Users who administer media"
}

resource "auth0_role" "download_viewers" {
  name        = "download-viewers"
  description = "Users who can view downloads"
}

resource "auth0_role" "download_admins" {
  name        = "download-admins"
  description = "Users who administer downloads"
}

resource "auth0_role" "monitoring_viewers" {
  name        = "monitoring-viewers"
  description = "Users who can view monitoring"
}

resource "auth0_role" "monitoring_admins" {
  name        = "monitoring-admins"
  description = "Users who administer monitoring"
}

resource "auth0_role" "storage_admins" {
  name        = "storage-admins"
  description = "Storage administrators"
}

resource "auth0_role" "cluster_admins" {
  name        = "cluster-admins"
  description = "Cluster administrators"
}

resource "auth0_role" "paperless" {
  name        = "paperless"
  description = "Paperless role"
}
