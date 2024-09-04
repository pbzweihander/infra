data "cloudflare_zone" "nineadw_org" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "9adw.org"
}

resource "aws_acm_certificate" "wiki_nineadw_org" {
  domain_name       = "wiki.9adw.org"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "wiki_nineadw_org_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wiki_nineadw_org.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.nineadw_org.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "kubernetes_namespace" "nineadw" {
  provider = kubernetes.strike_witches

  metadata {
    name = "nineadw"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

import {
  to = kubernetes_namespace.nineadw
  id = "nineadw"
}

