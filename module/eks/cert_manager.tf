resource "helm_release" "cert_manager" {
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.10.0"

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  wait = false

  set {
    name  = "installCRDs"
    value = "true"
  }
}
