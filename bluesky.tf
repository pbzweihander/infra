resource "cloudflare_record" "bluesky" {
  zone_id = data.cloudflare_zone.pbzweihander_dev.id
  name    = "_atproto"
  type    = "TXT"
  value   = "did=did:plc:6rduwvg3qmycpr5w556ddfhw"
  proxied = false
}
