resource "helm_release" "grafana_k8s_monitoring" {
  repository = "https://grafana.github.io/helm-charts"
  chart      = "k8s-monitoring"
  version    = "0.7.3"

  name             = "grafana-k8s-monitoring"
  namespace        = "grafana"
  create_namespace = true

  wait = false

  values = [yamlencode({
    cluster = {
      name = var.cluster_name
    }
    "grafana-agent-logs" = {
      controller = {
        tolerations = [
          {
            key      = "eks.amazonaws.com/compute-type"
            operator = "Equal"
            value    = "fargate"
            effect   = "NoExecute"
          },
        ]
      }
    }
    "prometheus-node-exporter" = {
      tolerations = [
        {
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoExecute"
        },
      ]
    }
    externalServices = {
      prometheus = {
        host = var.grafana_cloud_prometheus_host
        basicAuth = {
          username = var.grafana_cloud_prometheus_username
          password = var.grafana_cloud_token
        }
      }
      loki = {
        host = var.grafana_cloud_loki_host
        basicAuth = {
          username = var.grafana_cloud_loki_username
          password = var.grafana_cloud_token
        }
      }
      opencost = {
        opencost = {
          exporter = {
            defaultClusterId = var.cluster_name
            prometheus = {
              external = {
                url = "${var.grafana_cloud_prometheus_host}/api/prom"
              }
            }
          }
        }
      }
      logs = {
        pod_logs = {
          enabled = false
        }
      }
    }
  })]
}
