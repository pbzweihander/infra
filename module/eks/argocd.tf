resource "random_password" "argocd_server_admin_password" {
  length  = 42
  special = false
}

resource "bcrypt_hash" "argocd_server_admin_password" {
  cleartext = random_password.argocd_server_admin_password.result
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
    controller = {
      replicas = 1
    }
    server = {
      replicas = 1
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
      replicas = 1
    }
    applicationSet = {
      replicaCount = 1
    }
    configs = {
      params = {
        "server.insecure" = true
      }
      secret = {
        argocdServerAdminPassword = bcrypt_hash.argocd_server_admin_password.id
      }
    }
  })]
}
