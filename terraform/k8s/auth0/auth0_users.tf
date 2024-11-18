# resource "auth0_user" "user" {
#   for_each = var.users
#   email    = each.value.email
#   username = each.key
#
#   password          = each.value.password // Provide a default password or handle externally
#   connection_name   = "Username-Password-Authentication"
#   requires_username = true
# }
#
# resource "auth0_user_roles" "user_roles" {
#   for_each = var.users
#
#   user_id = auth0_user.user[each.key].id
#   roles   = []
#   #roles   = [for group in each.value.groups : auth0_role[group].id]
# }
