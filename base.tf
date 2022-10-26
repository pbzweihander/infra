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
