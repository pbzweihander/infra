resource "aws_route53_zone" "pbzweihander_dev" {
  name = "pbzweihander.dev"
}

resource "aws_route53_zone" "witches_dev" {
  name = "witches.dev"
}

resource "aws_route53_zone" "strike_witches_dev" {
  name = "strike.witches.dev"
}

resource "aws_route53_record" "strike_witches_dev_delegation" {
  zone_id = aws_route53_zone.witches_dev.zone_id
  name    = "strike"
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.strike_witches_dev.name_servers
}
