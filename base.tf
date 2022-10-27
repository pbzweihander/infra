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
      version = "~> 2.7.1"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.1.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "kubernetes" {
  host                   = module.strike_witches_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.strike_witches.token
}

provider "helm" {
  kubernetes {
    host                   = module.strike_witches_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.strike_witches_eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.strike_witches.token
  }
}

provider "kubectl" {
  host                   = module.strike_witches_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.strike_witches.token
  load_config_file       = false
}

data "aws_region" "current" {}
