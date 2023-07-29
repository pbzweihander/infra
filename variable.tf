variable "gmail_smtp_password" {
  type      = string
  sensitive = true
}

variable "cheph_github_client_id" {
  type      = string
  sensitive = true
}

variable "cheph_github_client_secret" {
  type      = string
  sensitive = true
}

variable "cheph_jwt_secret" {
  type      = string
  sensitive = true
}

variable "nanum_github_client_id" {
  type      = string
  sensitive = true
}

variable "nanum_github_client_secret" {
  type      = string
  sensitive = true
}

variable "nanum_jwt_secret" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "yuri_garden_contest_misskey_api_key" {
  type      = string
  sensitive = true
}
