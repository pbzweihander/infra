data "infisical_secrets" "mumble" {
  env_slug     = "prod"
  workspace_id = "ab9f0119-a250-4457-a479-36ded59e9aea"
  folder_path  = "/external-dns"
}

resource "helm_release" "external_dns" {
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.16.1"

  namespace        = "external-dns"
  name             = "external-dns"
  create_namespace = true

  wait = false

  values = [
    yamlencode({
      provider = {
        name = "cloudflare"
      }
      env = [
        {
          name  = "CF_API_TOKEN"
          value = data.infisical_secrets.mumble.secrets["CLOUDFLARE_API_TOKEN"].value
        }
      ]
      domainFilters = [
        "simian.rocks",
      ]
      policy = "sync"
    })
  ]
}
