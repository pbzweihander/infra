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