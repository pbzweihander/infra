resource "aws_acm_certificate" "wildcard_strike_witches_dev" {
  domain_name       = "*.strike.witches.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcard_strike_witches_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_strike_witches_dev.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.strike_witches_dev.zone_id
}
