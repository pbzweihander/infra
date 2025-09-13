resource "random_password" "jwt_secret" {
  length  = 42
  special = false
}

resource "helm_release" "fediq" {
  chart = "./chart"

  name             = "fediq"
  namespace        = "fediq"
  create_namespace = true

  description = sha1(join("", [for f in sort(fileset("./chart", "**")) : filesha1("./chart/${f}")]))

  wait = false

  values = [yamlencode({
    replicaCount = 2
    ingress = {
      enabled = true
      annotations = {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
        "traefik.ingress.kubernetes.io/router.tls"         = "true"
        "cert-manager.io/cluster-issuer"                   = "letsencrypt-prod"
      }
      className = "traefik"
      hosts = [{
        host = "fediq.pbzweihander.dev"
        paths = [{
          path     = "/"
          pathType = "Prefix"
        }]
      }]
      tls = [{
        secretName = "fediq-cert"
        hosts      = ["fediq.pbzweihander.dev"]
      }]
    }
    fediq = {
      publicUrl = "https://fediq.pbzweihander.dev"
      jwtSecret = random_password.jwt_secret.result
    }
  })]
}
