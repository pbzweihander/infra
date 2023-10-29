variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "managed_domain_hosted_zones" {
  type = list(any)
}

variable "eks_managed_node_group_defaults" {
  type = any
}

variable "eks_managed_node_groups" {
  type = any
}

variable "cloudflare_managed_domains" {
  type = list(string)
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "argocd_ingress_host" {
  type    = string
  default = ""
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
