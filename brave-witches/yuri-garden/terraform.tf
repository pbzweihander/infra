terraform {
  backend "s3" {
    bucket                      = "terraform"
    key                         = "brave-witches/yuri-garden.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    endpoints                   = { s3 = "https://4c92705a50dd61764cd79dac00dfcc60.r2.cloudflarestorage.com" }
  }

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }

    neon = {
      source  = "terraform-community-providers/neon"
      version = "0.1.8"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.45.0"
    }
  }
}

data "terraform_remote_state" "kubernetes" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "brave-witches/kubernetes.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    endpoints                   = { s3 = "https://4c92705a50dd61764cd79dac00dfcc60.r2.cloudflarestorage.com" }
  }
}

data "terraform_remote_state" "kubernetes_addons" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "brave-witches/kubernetes-addons.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    endpoints                   = { s3 = "https://4c92705a50dd61764cd79dac00dfcc60.r2.cloudflarestorage.com" }
  }
}

provider "helm" {
  kubernetes {
    host = "https://${data.terraform_remote_state.kubernetes.outputs.vke_cluster.endpoint}:6443"

    client_certificate     = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.cluster_ca_certificate)
  }
}

provider "neon" {
  token = var.neon_api_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
