locals {
  selector_labels = {
    "app.kubernetes.io/name"      = "rust-trending"
    "app.kubernetes.io/instance"  = "rust-trending"
    "app.kubernetes.io/component" = "bot"
  }
}

data "infisical_secrets" "rust_trending" {
  env_slug     = "prod"
  workspace_id = "ab9f0119-a250-4457-a479-36ded59e9aea"
  folder_path  = "/rust-trending"
}

resource "kubernetes_secret_v1" "secret" {
  depends_on = [helm_release.redis]

  metadata {
    namespace = "rust-trending"
    name      = "rust-trending"
  }

  type = "Opaque"

  data = {
    "config.toml" = <<-EOF
      [interval]
      post_ttl = 1209600
      fetch_interval = 7200
      post_interval = 3600

      [redis]
      url = "redis://:${random_password.redis_password.result}@rust-trending-redis-master:6379/0"

      [misskey]
      instance_url = "https://yuri.garden"
      access_token = "${data.infisical_secrets.rust_trending.secrets["MISSKEY_ACCESS_TOKEN"].value}"

      [bluesky]
      host = "https://bsky.social"
      identifier = "rusttrending.bsky.social"
      password = "${data.infisical_secrets.rust_trending.secrets["BLUESKY_PASSWORD"].value}"

      [denylist]
      names = []
      authors = ["rust-lang", "sunface", "phodal"]
      descriptions = [
        "ethereum",
        "block chain",
        "blockchain",
        "cryptocurrency",
        "smart contract",
      ]
    EOF
  }
}

resource "kubernetes_deployment_v1" "bot" {
  depends_on = [
    helm_release.redis,
    kubernetes_secret_v1.secret,
  ]

  wait_for_rollout = false

  metadata {
    namespace = "rust-trending"
    name      = "rust-trending-bot"
    labels    = local.selector_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.selector_labels
    }
    template {
      metadata {
        labels = local.selector_labels
      }
      spec {
        container {
          name              = "bot"
          image             = "ghcr.io/pbzweihander/rust-trending:latest"
          image_pull_policy = "Always"
          command           = ["rust-trending", "/config/config.toml"]
          env {
            name  = "RUST_LOG"
            value = "info"
          }
          env {
            name  = "RUST_BACKTRACE"
            value = "1"
          }
          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }
        }
        volume {
          name = "config"
          secret {
            secret_name = "rust-trending"
          }
        }
      }
    }
  }
}

