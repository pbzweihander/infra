locals {
  rust_kr_discord_irc_selector_labels = {
    "app.kubernetes.io/name"      = "discord-irc"
    "app.kubernetes.io/instance"  = "rust-kr-discord-irc"
    "app.kubernetes.io/component" = "bot"
  }
}

resource "kubernetes_namespace" "rust_kr_discord_irc" {
  provider = kubernetes.strike_witches

  metadata {
    name = "rust-kr-discord-irc"
  }
}

resource "kubernetes_deployment" "rust_kr_discord_irc" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = kubernetes_namespace.rust_kr_discord_irc.metadata[0].name
    name      = "discord-irc"
    labels    = local.rust_kr_discord_irc_selector_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.rust_kr_discord_irc_selector_labels
    }
    template {
      metadata {
        labels = local.rust_kr_discord_irc_selector_labels
      }
      spec {
        container {
          name  = "bot"
          image = "ghcr.io/pbzweihander/discord-irc-rs:8bd6c8ef121038ceecab470ca36fa43a8301a217"
          volume_mount {
            name       = "config"
            mount_path = "/a"
            read_only  = true
          }
        }
        volume {
          name = "config"
          secret {
            secret_name = "discord-irc"
          }
        }
      }
    }
  }
}
