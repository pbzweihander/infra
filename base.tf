provider "aws" {
  version = "~> 2.23"
  region  = "ap-northeast-1"
}

terraform {
  required_version = "~> 0.12.6"

  backend "remote" {
    organization = "pbzweihander"

    workspaces {
      name = "infra"
    }
  }
}
