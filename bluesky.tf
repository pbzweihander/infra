resource "aws_route53_record" "bluesky" {
  zone_id = aws_route53_zone.pbzweihander_dev.zone_id
  name    = "_atproto"
  type    = "TXT"
  ttl     = 300
  records = ["did=did:plc:6rduwvg3qmycpr5w556ddfhw"]
}
