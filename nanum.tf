locals {
  nanum_domain = "nanum.pbzweihander.dev"

  nanum_namespace           = "nanum"
  nanum_service_name        = "nanum"
  nanum_serviceaccount_name = "nanum"

  nanum_labels = {
    "app.kubernetes.io/name"      = "nanum"
    "app.kubernetes.io/instance"  = "nanum"
    "app.kubernetes.io/component" = "backend"
  }

  nanum_allowed_emails = [
    "pbzweihander@gmail.com",
  ]
}

resource "aws_acm_certificate" "nanum_pbzweihander_dev" {
  domain_name       = local.nanum_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "nanum_pbzweihander_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.nanum_pbzweihander_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.pbzweihander_dev.zone_id
}

resource "aws_s3_bucket" "nanum" {
  bucket_prefix = "pbzweihander-nanum-"
}

data "aws_iam_policy_document" "nanum" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.nanum.arn}",
      "${aws_s3_bucket.nanum.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "nanum" {
  name_prefix = "nanum"
  policy      = data.aws_iam_policy_document.nanum.json
}

data "aws_iam_policy_document" "nanum_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.strike_witches_eks.eks_cluster_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.strike_witches_eks.eks_cluster_oidc_provider}:sub"

      values = [
        "system:serviceaccount:${local.nanum_namespace}:${local.nanum_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "nanum" {
  name_prefix        = "nanum"
  assume_role_policy = data.aws_iam_policy_document.nanum_assume.json
}

resource "aws_iam_role_policy_attachment" "nanum" {
  role       = aws_iam_role.nanum.name
  policy_arn = aws_iam_policy.nanum.arn
}

resource "kubernetes_namespace" "nanum" {
  provider = kubernetes.strike_witches

  metadata {
    name = local.nanum_namespace
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubernetes_service_account" "nanum" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.nanum,
  ]

  metadata {
    namespace = local.nanum_namespace
    name      = local.nanum_serviceaccount_name
    labels    = local.nanum_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.nanum.arn
    }
  }
}

resource "kubernetes_secret" "nanum" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.nanum,
  ]

  metadata {
    namespace = local.nanum_namespace
    name      = "nanum"
    labels    = local.nanum_labels
  }

  data = {
    GITHUB_CLIENT_ID     = var.nanum_github_client_id
    GITHUB_CLIENT_SECRET = var.nanum_github_client_secret
    JWT_SECRET           = var.nanum_jwt_secret
  }
}

resource "kubernetes_deployment" "nanum" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.nanum,
    kubernetes_service_account.nanum,
    kubernetes_secret.nanum,
  ]

  metadata {
    namespace = local.nanum_namespace
    name      = "nanum"
    labels    = local.nanum_labels
  }
  spec {
    replicas = 2
    selector {
      match_labels = local.nanum_labels
    }
    template {
      metadata {
        labels = local.nanum_labels
      }
      spec {
        service_account_name = local.nanum_serviceaccount_name
        container {
          name  = "backend"
          image = "ghcr.io/pbzweihander/nanum:340373bbc89e32ed0b587c8efcc97bfb8800946e"
          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }
          liveness_probe {
            tcp_socket {
              port = "http"
            }
          }
          readiness_probe {
            http_get {
              path = "/api/health"
              port = "http"
            }
          }
          env {
            name  = "ALLOWED_EMAILS"
            value = join(",", local.nanum_allowed_emails)
          }
          env {
            name  = "PUBLIC_URL"
            value = "https://${local.nanum_domain}"
          }
          env {
            name  = "S3_BUCKET_NAME"
            value = aws_s3_bucket.nanum.id
          }
          env_from {
            secret_ref {
              name = "nanum"
            }
          }
        }
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              pod_affinity_term {
                label_selector {
                  match_labels = local.nanum_labels
                }
                topology_key = "topology.kubernetes.io/zone"
              }
              weight = 100
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nanum" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.nanum,
  ]

  metadata {
    namespace = local.nanum_namespace
    name      = local.nanum_service_name
    labels    = local.nanum_labels
    annotations = {
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
    }
  }
  spec {
    type = "ClusterIP"
    port {
      name        = "http"
      port        = 3000
      target_port = "http"
      protocol    = "TCP"
    }
    selector = local.nanum_labels
  }
}

resource "kubernetes_ingress_v1" "nanum" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.nanum,
  ]

  metadata {
    namespace = local.nanum_namespace
    name      = "nanum"
    labels    = local.nanum_labels
    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect" = "443"
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = local.nanum_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = local.nanum_service_name
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}
