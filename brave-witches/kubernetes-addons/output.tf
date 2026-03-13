output "ingress_external_ip" {
  value = data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip
}

output "ingress_external_ipv6" {
  value = data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[1].ip
}
