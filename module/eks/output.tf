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

output "eks_cluster_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_cluster_oidc_provider" {
  value = module.eks.oidc_provider
}
