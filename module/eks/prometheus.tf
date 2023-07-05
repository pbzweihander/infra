resource "helm_release" "prometheus" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  name             = "prometheus"
  namespace        = "prometheus"
  create_namespace = true

  values = [yamlencode({
    server = {
      remoteWrite = [{
        url = "http://openobserve-router.${local.openobserve_namespace}.svc.cluster.local:5080/api/default/prometheus/api/v1/write"
        basic_auth = {
          username = "pbzweihander@gmail.com"
          password = random_password.openobserve.result
        }
      }]
    }
  })]
}
