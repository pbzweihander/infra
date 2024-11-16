resource "helm_release" "traefik" {
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "33.0.0"

  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true

  wait = false

  values = [yamlencode({
    service = {
      annotations = {
        "service.beta.kubernetes.io/vultr-loadbalancer-sticky-session-enabled"     = "on"
        "service.beta.kubernetes.io/vultr-loadbalancer-sticky-session-cookie-name" = "vultr-sticky"
      }
    }
  })]
}

data "kubernetes_service" "traefik" {
  metadata {
    namespace = "traefik"
    name      = "traefik"
  }
}
