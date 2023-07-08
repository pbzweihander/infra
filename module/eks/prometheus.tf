resource "helm_release" "prometheus" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  name             = "prometheus"
  namespace        = "prometheus"
  create_namespace = true
}
