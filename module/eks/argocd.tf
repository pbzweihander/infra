resource "random_password" "argocd_server_admin_password" {
  length  = 42
  special = false
}

resource "helm_release" "argocd" {
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.39.0"

  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  wait = false

  values = [yamlencode({
    redis-ha = {
      enabled = true
    }
    controller = {
      replicas = 1
    }
    server = {
      replicas = 2
      ingress = var.argocd_ingress_host == "" ? null : {
        enabled          = true
        ingressClassName = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"  = "ip"
          "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect" = "443"
        }
        hosts = [var.argocd_ingress_host]
      }
    }
    repoServer = {
      replicas = 2
    }
    applicationSet = {
      replicaCount = 2
    }
    configs = {
      params = {
        "server.insecure" = true
      }
      secret = {
        argocdServerAdminPassword = bcrypt(random_password.argocd_server_admin_password.result)
      }
    }
  })]
}
