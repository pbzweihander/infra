resource "cloudflare_record" "ommrema_9adw_org" {
  zone_id = "6737e624d3318dc7fa6c0fefd06382f5"
  name    = "ommrema"
  content = data.terraform_remote_state.kubernetes_addons.outputs.ingress_external_ip
  type    = "A"
  proxied = false
}
