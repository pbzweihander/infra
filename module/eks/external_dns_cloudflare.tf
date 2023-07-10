resource "helm_release" "external_dns_cloudflare" {
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.11.2"

  namespace        = "external-dns-cloudflare"
  name             = "external-dns"
  create_namespace = true

  wait = false

  values = [
    yamlencode({
      sources = [
        "ingress",
      ]
      provider = "cloudflare"
      cloudflare = {
        apiToken = var.cloudflare_api_token
        proxied  = false
      }
      rbac = {
        create = true
      }
      domainFilters = var.cloudflare_managed_domains
      policy        = "sync"
    })
  ]
}
