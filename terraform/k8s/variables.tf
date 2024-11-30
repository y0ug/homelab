variable "oauth2_proxy_cookie_secret" {
  type = string
}

variable "scw_project_id" {
  type = string
}

variable "users" {
  type = map(object({
    email = string
    #password = string
    groups = list(string)
  }))
}

variable "cf_account_id" {
  type = string
}
