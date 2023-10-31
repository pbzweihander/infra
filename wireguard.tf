resource "kubernetes_namespace" "wireguard" {
  provider = kubernetes.strike_witches

  metadata {
    name = "wireguard"
  }
}

resource "kubectl_manifest" "wireguard_project" {
  provider = kubectl.strike_witches

  depends_on = [
    kubernetes_namespace.wireguard,
  ]

  yaml_body = file("argocd/wireguard/project.yaml")
}

resource "kubectl_manifest" "wireguard" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.wireguard_project
  ]

  yaml_body = file("argocd/wireguard/wireguard.yaml")
}
