resource "aws_acm_certificate" "pbzweihander_dev" {
  domain_name       = "pbzweihander.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "pbzweihander_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.pbzweihander_dev.domain_validation_options : dvo.domain_name => {
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

resource "kubernetes_ingress_v1" "pbzweihander_dev" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = "default"
    name      = "pbzweihander-dev"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                     = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"                = "ip"
      "alb.ingress.kubernetes.io/listen-ports"               = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"               = "443"
      "alb.ingress.kubernetes.io/actions.redirect-mastodon" = <<EOT
{"type":"redirect","redirectConfig":{"protocol":"HTTPS","host":"mastodon.pbzweihander.dev","port":"443","statusCode":"HTTP_301"}}
EOT
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = "pbzweihander.dev"
      http {
        path {
          path      = "/.well-known/webfinger"
          path_type = "Exact"
          backend {
            service {
              name = "redirect-mastodon"
              port {
                name = "use-annotation"
              }
            }
          }
        }
        path {
          path      = "/@pbzweihander"
          path_type = "Exact"
          backend {
            service {
              name = "redirect-mastodon"
              port {
                name = "use-annotation"
              }
            }
          }
        }
      }
    }
  }
}
