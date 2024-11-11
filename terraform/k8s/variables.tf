variable "oauth2_proxy_cookie_secret" {
  type = string
}

variable "scw_project_id" {
  type    = string
  default = "802b6dc7-d07d-45cc-be79-8822053fdf71"
}

variable "users" {
  type = map(object({
    email = string
    #password = string
    groups = list(string)
  }))
}


