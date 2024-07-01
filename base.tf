terraform {
  required_version = "~> 1.8.5"

  backend "remote" {
    organization = "pbzweihander"

    workspaces {
      name = "infra"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56.1"
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

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.17.0"
    }

    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = "~> 0.1.2"
    }

    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 1.3.1"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias = "us_east_1"

  region = "us-east-1"
}

provider "kubernetes" {
  alias = "strike_witches"

  host                   = module.strike_witches_eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.strike_witches_eks.eks_cluster_name,
    ]
  }
}

provider "helm" {
  alias = "strike_witches"

  kubernetes {
    host                   = module.strike_witches_eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.strike_witches_eks.eks_cluster_name,
      ]
    }
  }

  experiments {
    manifest = true
  }
}

provider "kubectl" {
  alias = "strike_witches"

  host                   = module.strike_witches_eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.strike_witches_eks.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.strike_witches_eks.eks_cluster_name,
    ]
  }

  load_config_file = false
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
  op_cli_path           = "${path.module}/bin/op"
}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "onepassword_vault" "strike_witches" {
  name = "strike-witches"
}
