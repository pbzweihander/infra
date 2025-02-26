resource "random_password" "redis_password" {
  length  = 20
  special = false
}

resource "helm_release" "redis" {
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "redis"
  version    = "20.9.0"

  name             = "redis"
  namespace        = "rust-trending"
  create_namespace = true

  wait = false

  values = [yamlencode({
    fullnameOverride = "rust-trending-redis"
    architecture     = "standalone"
    auth = {
      password = random_password.redis_password.result
    }
    master = {
      persistence = {
        size = "40Gi"
      }
    }
  })]
}
