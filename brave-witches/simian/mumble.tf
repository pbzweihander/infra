data "infisical_secrets" "mumble" {
  env_slug     = "prod"
  workspace_id = "ab9f0119-a250-4457-a479-36ded59e9aea"
  folder_path  = "/simian/mumble"
}

resource "helm_release" "mumble" {
  chart = "./charts/mumble"

  name             = "mumble"
  namespace        = "simian"
  create_namespace = true

  description = sha1(join("", [for f in sort(fileset("./charts/mumble", "**")) : filesha1("./charts/mumble/${f}")]))

  wait = false

  values = [yamlencode({
    domain            = "mumble.simian.rocks"
    serverPassword    = data.infisical_secrets.mumble.secrets["SERVER_PASSWORD"].value
    superuserPassword = data.infisical_secrets.mumble.secrets["SUPERUSER_PASSWORD"].value
  })]
}
