terraform {
  backend "s3" {
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

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.21.0"
    }

    local = {
      source = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}
