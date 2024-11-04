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
      host     = vultr_database.misskey_202411_1.host
      port     = vultr_database.misskey_202411_1.port
      database = vultr_database.misskey_202411_1.dbname
      username = vultr_database.misskey_202411_1.user
      password = vultr_database.misskey_202411_1.password
      extras = {
        statement_timeout = 0
        ssl = {
          rejectUnauthorized = false
        }
      }
      replicas = [
        {
          host     = vultr_database_replica.misskey_202411_1_0.host
          port     = vultr_database_replica.misskey_202411_1_0.port
          database = vultr_database_replica.misskey_202411_1_0.dbname
          username = vultr_database_replica.misskey_202411_1_0.user
          password = vultr_database_replica.misskey_202411_1_0.password
        },
        {
          host     = vultr_database_replica.misskey_202411_1_1.host
          port     = vultr_database_replica.misskey_202411_1_1.port
          database = vultr_database_replica.misskey_202411_1_1.dbname
          username = vultr_database_replica.misskey_202411_1_1.user
          password = vultr_database_replica.misskey_202411_1_1.password
        },
      ]
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
