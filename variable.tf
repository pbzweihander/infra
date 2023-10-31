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

variable "aquarium_yuri_garden_r2_access_key" {
  type      = string
  sensitive = true
}

variable "aquarium_yuri_garden_r2_access_secret" {
  type      = string
  sensitive = true
}

variable "aquarium_yuri_garden_r2_endpoint" {
  type = string
}

variable "aquarium_yuri_garden_vapid_private_key" {
  type      = string
  sensitive = true
}

variable "aquarium_yuri_garden_vapid_public_key" {
  type      = string
  sensitive = true
}

variable "aquarium_yuri_garden_smtp_login" {
  type      = string
  sensitive = true
}

variable "aquarium_yuri_garden_smtp_password" {
  type      = string
  sensitive = true
}

variable "notification_slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "grafana_cloud_prometheus_host" {
  type = string
}

variable "grafana_cloud_prometheus_username" {
  type      = string
  sensitive = true
}

variable "grafana_cloud_loki_host" {
  type = string
}

variable "grafana_cloud_loki_username" {
  type      = string
  sensitive = true
}

variable "grafana_cloud_token" {
  type      = string
  sensitive = true
}

variable "iframely_api_key" {
  type      = string
  sensitive = true
}
