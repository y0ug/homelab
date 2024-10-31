locals {
  groups_mapping = {
    authentik-admins   = data.authentik_group.authentik_admins.id
    users              = authentik_group.users.id
    media-viewers      = authentik_group.media_viewers.id
    media-admins       = authentik_group.media_admins.id
    download-viewers   = authentik_group.download_viewers.id
    download-admins    = authentik_group.download_admins.id
    monitoring-viewers = authentik_group.monitoring_viewers.id
    monitoring-admins  = authentik_group.monitoring_admins.id
    storage-admins     = authentik_group.storage_admins.id
    cluster-admins     = authentik_group.cluster_admins.id
    paperless          = authentik_group.paperless.id
  }
}

resource "authentik_user" "name" {
  for_each = var.users
  username = each.key
  name     = each.key
  email    = each.value.email
  groups   = [for group in each.value.groups : local.groups_mapping[group]]
}
