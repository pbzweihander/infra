resource "helm_release" "onepassword_injector" {
  repository = "https://1password.github.io/connect-helm-charts"
  chart      = "secrets-injector"
  version    = "1.0.1"

  name             = "1password-injector"
  namespace        = "1password"
  create_namespace = true

  wait = false
}
