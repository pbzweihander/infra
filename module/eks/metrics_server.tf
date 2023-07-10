resource "helm_release" "metrics_server" {
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.8.2"

  name             = "metrics-server"
  namespace        = "metrics-server"
  create_namespace = true

  wait = false
}
