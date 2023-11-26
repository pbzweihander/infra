resource "aws_acm_certificate" "fediq_pbzweihander_dev" {
  domain_name       = "fediq.pbzweihander.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "fediq_pbzweihander_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.fediq_pbzweihander_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.pbzweihander_dev.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "kubernetes_namespace" "fediq" {
  provider = kubernetes.strike_witches

  metadata {
    name = "fediq"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubectl_manifest" "fediq_project" {
  provider = kubectl.strike_witches

  depends_on = [
    kubernetes_namespace.fediq,
  ]

  yaml_body = file("argocd/fediq/project.yaml")
}

resource "random_password" "fediq_jwt_secret" {
  length = 42
}

resource "kubectl_manifest" "fediq" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.fediq_project,
  ]

  yaml_body = templatefile(
    "argocd/fediq/fediq.yaml",
    {
      jwtSecret = random_password.fediq_jwt_secret.result
    },
  )
}
