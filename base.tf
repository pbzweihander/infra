provider "aws" {
  region = "ap-northeast-1"
}

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
  }
}
