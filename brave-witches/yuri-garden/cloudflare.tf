resource "cloudflare_record" "yuri_garden" {
  zone_id = "f19f35bcaeeb1a6d25a261afe4e151a1"
  name    = "@"
  content = data.terraform_remote_state.kubernetes_addons.outputs.ingress_external_ip
  type    = "A"
  proxied = false
}
