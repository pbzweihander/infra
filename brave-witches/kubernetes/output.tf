output "vke_cluster" {
  value     = vultr_kubernetes.this
  sensitive = true
}
