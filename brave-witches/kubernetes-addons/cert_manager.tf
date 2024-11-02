resource "helm_release" "cert_manager" {
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.16.1"

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  wait = false

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_manifest" "cert_manager_issuer" {
  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = "pbzweihander@protonmail.com"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "traefik"
              }
            }
          }
        ]
      }
    }
  }
}
