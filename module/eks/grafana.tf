resource "helm_release" "grafana" {
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  name             = "grafana"
  namespace        = "grafana"
  create_namespace = true
}
