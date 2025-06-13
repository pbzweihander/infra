terraform {
  backend "s3" {
    bucket                      = "terraform"
    key                         = "brave-witches/simian.tfstate"
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
      source = "hashicorp/helm"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
    }

    infisical = {
      source = "Infisical/infisical"
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

provider "kubernetes" {
  host = "https://${data.terraform_remote_state.kubernetes.outputs.vke_cluster.endpoint}:6443"

  client_certificate     = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = "https://${data.terraform_remote_state.kubernetes.outputs.vke_cluster.endpoint}:6443"

    client_certificate     = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.kubernetes.outputs.vke_cluster.cluster_ca_certificate)
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "infisical" {
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}
