provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_version = "~> 1.0.8"

  backend "remote" {
    organization = "pbzweihander"

    workspaces {
      name = "infra"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.66.0"
    }
  }
}
