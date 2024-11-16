data "infisical_secrets" "ommrema" {
  env_slug     = "prod"
  workspace_id = "ab9f0119-a250-4457-a479-36ded59e9aea"
  folder_path  = "/9adw/ommrema"
}

resource "random_password" "ommrema_jwt_secret" {
  length  = 20
  special = false
}

resource "helm_release" "ommrema" {
  chart = "./charts/ommrema"

  name             = "ommrema"
  namespace        = "nineadw"
  create_namespace = true

  description = sha1(join("", [for f in sort(fileset("./charts/ommrema", "**")) : filesha1("./charts/ommrema/${f}")]))

  wait = false

  values = [yamlencode({
    jwtSecret = random_password.ommrema_jwt_secret.result
    discord = {
      clientId     = data.infisical_secrets.ommrema.secrets["DISCORD_CLIENT_ID"].value
      clientSecret = data.infisical_secrets.ommrema.secrets["DISCORD_CLIENT_SECRET"].value
      guildId      = data.infisical_secrets.ommrema.secrets["DISCORD_GUILD_ID"].value
      guildRoleId  = data.infisical_secrets.ommrema.secrets["DISCORD_GUILD_ROLE_ID"].value
    }
    s3 = {
      bucket          = "9adw-ommrema"
      accessKeyId     = data.infisical_secrets.ommrema.secrets["S3_ACCESS_KEY_ID"].value
      secretAccessKey = data.infisical_secrets.ommrema.secrets["S3_SECRET_ACCESS_KEY"].value
      region          = "auto"
      endpoint        = "https://4c92705a50dd61764cd79dac00dfcc60.r2.cloudflarestorage.com"
    }
  })]
}
