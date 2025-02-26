resource "vultr_kubernetes" "this" {
  region  = "icn"
  label   = "brave-witches"
  version = "v1.31.0+1"

  ha_controlplanes = true
  enable_firewall  = true

  node_pools {
    node_quantity = 2
    plan          = "vc2-2c-2gb"
    label         = "bw"
    auto_scaler   = true
    min_nodes     = 2
    max_nodes     = 5
  }

  lifecycle {
    ignore_changes = [
      node_pools[0].node_quantity,
    ]
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content_base64  = vultr_kubernetes.this.kube_config
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}
