locals {
  rust_trending_bot_selector_labels = {
    "app.kubernetes.io/name"      = "rust-trending"
    "app.kubernetes.io/instance"  = "rust-trending"
    "app.kubernetes.io/component" = "bot"
  }
  rust_trending_redis_selector_labels = {
    "app.kubernetes.io/name"      = "rust-trending"
    "app.kubernetes.io/instance"  = "rust-trending"
    "app.kubernetes.io/component" = "redis"
  }
}

resource "kubernetes_namespace" "rust_trending" {
  provider = kubernetes.strike_witches

  metadata {
    name = "rust-trending"
  }
}

resource "kubernetes_deployment" "rust_trending_bot" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = kubernetes_namespace.rust_trending.metadata[0].name
    name      = "rust-trending-bot"
    labels    = local.rust_trending_bot_selector_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.rust_trending_bot_selector_labels
    }
    template {
      metadata {
        labels = local.rust_trending_bot_selector_labels
      }
      spec {
        container {
          name    = "bot"
          image   = "ghcr.io/pbzweihander/rust-trending:ec5a8882c82e31cec178fc97c55d1bc01294a47a"
          command = ["rust-trending", "/config/config.toml"]
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

resource "kubernetes_deployment" "rust_trending_redis" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = kubernetes_namespace.rust_trending.metadata[0].name
    name      = "rust-trending-redis"
    labels    = local.rust_trending_redis_selector_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.rust_trending_redis_selector_labels
    }
    template {
      metadata {
        labels = local.rust_trending_redis_selector_labels
      }
      spec {
        container {
          name  = "redis"
          image = "redis:4-alpine"
          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "rust_trending_redis" {
  provider = kubernetes.strike_witches

  metadata {
    namespace = kubernetes_namespace.rust_trending.metadata[0].name
    name      = "rust-trending-redis"
    labels    = local.rust_trending_redis_selector_labels
  }
  spec {
    type     = "ClusterIP"
    selector = local.rust_trending_redis_selector_labels
    port {
      port        = 6379
      protocol    = "TCP"
      target_port = 6379
    }
  }
}
