resource "helm_release" "traefik" {
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "33.0.0"

  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true

  wait = false

  values = [yamlencode({
    ports = {
      web = {
        redirectTo = {
          port = "websecure"
        }
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
