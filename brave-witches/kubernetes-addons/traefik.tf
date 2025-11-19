resource "helm_release" "traefik" {
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "37.3.0"

  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true

  wait = false

  values = [yamlencode({
    deployment = {
      replicas = 3
    }
    podDisruptionBudget = {
      enabled = true
      minAvailable = 1
    }
    service = {
      annotations = {
        "service.beta.kubernetes.io/vultr-loadbalancer-sticky-session-enabled"     = "on"
        "service.beta.kubernetes.io/vultr-loadbalancer-sticky-session-cookie-name" = "vultr-sticky"
      }
    }
    ports = {
      websecure = {
        transport = {
          respondingTimeouts = {
            readTimeout = 0
          }
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
