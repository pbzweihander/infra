terraform {
  required_version = "~> 1.3.3"

  backend "remote" {
    organization = "pbzweihander"

    workspaces {
      name = "infra"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.36.1"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.3"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.14.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.1.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "kubernetes" {
  alias = "strike_witches"

  host                   = module.strike_witches_eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)
  token                  = module.strike_witches_eks.eks_cluster_auth_token
}

provider "helm" {
  alias = "strike_witches"

  kubernetes {
    host                   = module.strike_witches_eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)
    token                  = module.strike_witches_eks.eks_cluster_auth_token
  }

  experiments {
    manifest = true
  }
}

provider "kubectl" {
  alias = "strike_witches"

  host                   = module.strike_witches_eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)
  token                  = module.strike_witches_eks.eks_cluster_auth_token
  load_config_file       = false
}

data "aws_region" "current" {}
