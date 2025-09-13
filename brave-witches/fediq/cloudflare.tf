resource "cloudflare_dns_record" "fediq" {
  zone_id = "f12b839469a681f4e5bacd83ced239de"
  name    = "fediq"
  content = data.terraform_remote_state.kubernetes_addons.outputs.ingress_external_ip
  type    = "A"
  ttl     = 300
  proxied = false
}
