locals {
  cheph_domain = "cheph.pbzweihander.dev"

  cheph_namespace           = "cheph"
  cheph_service_name        = "cheph"
  cheph_serviceaccount_name = "cheph"

  cheph_labels = {
    "app.kubernetes.io/name"      = "cheph"
    "app.kubernetes.io/instance"  = "cheph"
    "app.kubernetes.io/component" = "backend"
  }

  cheph_allowed_emails = [
    "pbzweihander@gmail.com",
  ]
}

resource "aws_acm_certificate" "cheph_pbzweihander_dev" {
  domain_name       = local.cheph_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cheph_pbzweihander_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cheph_pbzweihander_dev.domain_validation_options : dvo.domain_name => {
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

resource "aws_s3_bucket" "cheph" {
  bucket_prefix = "pbzweihander-cheph"
}

data "aws_iam_policy_document" "cheph" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.cheph.arn}",
      "${aws_s3_bucket.cheph.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "cheph" {
  name_prefix = "cheph"
  policy      = data.aws_iam_policy_document.cheph.json
}

data "aws_iam_policy_document" "cheph_assume" {
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
        "system:serviceaccount:${local.cheph_namespace}:${local.cheph_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "cheph" {
  name_prefix        = "cheph"
  assume_role_policy = data.aws_iam_policy_document.cheph_assume.json
}

resource "aws_iam_role_policy_attachment" "cheph" {
  role       = aws_iam_role.cheph.name
  policy_arn = aws_iam_policy.cheph.arn
}

resource "kubernetes_namespace" "cheph" {
  provider = kubernetes.strike_witches

  metadata {
    name = local.cheph_namespace
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubernetes_service_account" "cheph" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.cheph,
  ]

  metadata {
    namespace = local.cheph_namespace
    name      = local.cheph_serviceaccount_name
    labels    = local.cheph_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cheph.arn
    }
  }
}

resource "kubernetes_deployment" "cheph" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.cheph,
  ]

  metadata {
    namespace = local.cheph_namespace
    name      = "cheph"
    labels    = local.cheph_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.cheph_labels
    }
    template {
      metadata {
        labels = local.cheph_labels
      }
      spec {
        service_account_name = local.cheph_serviceaccount_name
        container {
          name              = "backend"
          image             = "ghcr.io/pbzweihander/cheph:latest"
          image_pull_policy = "Always"
          port {
            name           = "http"
            container_port = 3001
            protocol       = "TCP"
          }
          liveness_probe {
            tcp_socket {
              port = "http"
            }
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
          }
          env {
            name  = "ALLOWED_EMAILS"
            value = join(",", local.cheph_allowed_emails)
          }
          env {
            name  = "GITHUB_CLIENT_ID"
            value = var.cheph_github_client_id
          }
          env {
            name  = "GITHUB_CLIENT_SECRET"
            value = var.cheph_github_client_secret
          }
          env {
            name  = "PUBLIC_URL"
            value = "https://${local.cheph_domain}"
          }
          env {
            name  = "JWT_SECRET"
            value = var.cheph_jwt_secret
          }
          env {
            name  = "S3_BUCKET_NAME"
            value = aws_s3_bucket.cheph.id
          }
        }
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              pod_affinity_term {
                label_selector {
                  match_labels = local.cheph_labels
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

resource "kubernetes_service" "cheph" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.cheph,
  ]

  metadata {
    namespace = local.cheph_namespace
    name      = local.cheph_service_name
    labels    = local.cheph_labels
    annotations = {
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
    }
  }
  spec {
    type = "ClusterIP"
    port {
      name        = "http"
      port        = 3001
      target_port = "http"
      protocol    = "TCP"
    }
    selector = local.cheph_labels
  }
}

resource "kubernetes_ingress_v1" "cheph" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.cheph,
  ]

  metadata {
    namespace = local.cheph_namespace
    name      = "cheph"
    labels    = local.cheph_labels
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
      host = local.cheph_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = local.cheph_service_name
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
