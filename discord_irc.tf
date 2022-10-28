locals {
  discord_irc_selector_labels = {
    "app.kubernetes.io/name"      = "discord-irc"
    "app.kubernetes.io/instance"  = "discord-irc"
    "app.kubernetes.io/component" = "bot"
  }
}

resource "kubernetes_namespace" "discord_irc" {
  provider = kubernetes.strike_witches

  metadata {
    name = "discord-irc"
  }
}

resource "kubernetes_deployment" "discord_irc" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = kubernetes_namespace.discord_irc.metadata[0].name
    name      = "discord-irc"
    labels    = local.discord_irc_selector_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.discord_irc_selector_labels
    }
    template {
      metadata {
        labels = local.discord_irc_selector_labels
      }
      spec {
        container {
          name  = "bot"
          image = "ghcr.io/pbzweihander/discord-irc-rs:0ed3b1e20f9f3567e2231223aae14f84f650cd7f"
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
