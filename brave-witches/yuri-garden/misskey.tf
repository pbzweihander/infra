resource "random_password" "misskey_redis" {
  length = 20
}

resource "random_password" "misskey_meilisearch" {
  length = 20
}

resource "helm_release" "misskey" {
  chart = "./charts/misskey"

  name             = "yuri-garden-misskey"
  namespace        = "yuri-garden"
  create_namespace = true

  description = sha1(join("", [for f in sort(fileset("./charts/misskey", "**")) : filesha1("./charts/misskey/${f}")]))

  dependency_update = true
  wait              = false

  values = [yamlencode({
    image = {
      tag = "2024.8.0-yurigarden.0"
    }
    database = {
      host     = neon_project.this.branch.endpoint.host
      database = neon_database.misskey.name
      username = neon_role.this.name
      password = neon_role.this.password
    }
    redis = {
      auth = {
        password = random_password.misskey_redis.result
      }
    }
    meilisearch = {
      environment = {
        MEILI_MASTER_KEY = random_password.misskey_meilisearch.result
      }
    }
  })]
}
