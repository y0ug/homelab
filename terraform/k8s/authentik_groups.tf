data "authentik_group" "authentik_admins" {
  name = "authentik Admins"
}

resource "authentik_group" "users" {
  name = "users"
}

resource "authentik_group" "media_viewers" {
  name = "media-viewers"
}

resource "authentik_group" "media_admins" {
  name = "media-admins"
}

resource "authentik_group" "download_viewers" {
  name = "download-viewers"
}

resource "authentik_group" "download_admins" {
  name = "download-admins"
}

resource "authentik_group" "monitoring_viewers" {
  name = "monitoring-viewers"
}

resource "authentik_group" "monitoring_editors" {
  name = "monitoring-editors"
}

resource "authentik_group" "monitoring_admins" {
  name = "monitoring-admins"
}

resource "authentik_group" "storage_admins" {
  name = "storage-admins"
}

resource "authentik_group" "cluster_admins" {
  name = "cluster-admins"
}

resource "authentik_group" "paperless" {
  name = "paperless"
}

