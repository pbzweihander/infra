output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_auth_token" {
  value     = data.aws_eks_cluster_auth.this.token
  sensitive = true
}
