locals {
  mastodon_namespace           = "mastodon"
  mastodon_serviceaccount_name = "mastodon"
  mastodon_web_domain          = "mastodon.pbzweihander.dev"

  // https://github.com/hashicorp/terraform-provider-helm/issues/515#issuecomment-1237328171
  mastodon_chart_path = "./chart/mastodon"
  mastodon_chart_hash = md5(join("", [
    for f in fileset(local.mastodon_chart_path, "**") :
    filemd5(format("%s/%s", local.mastodon_chart_path, f))
  ]))
}

resource "aws_acm_certificate" "mastodon_pbzweihander_dev" {
  domain_name       = "mastodon.pbzweihander.dev"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "mastodon_pbzweihander_dev_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.mastodon_pbzweihander_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.pbzweihander_dev.zone_id
}

resource "aws_db_parameter_group" "mastodon" {
  name   = "mastodon"
  family = "aurora-postgresql14"
}

resource "aws_rds_cluster_parameter_group" "mastodon" {
  name   = "mastodon"
  family = "aurora-postgresql14"
}

module "mastodon_rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 7.6.0"

  name              = "mastodon"
  engine            = data.aws_rds_engine_version.aurora_postgresql_14_4.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.aurora_postgresql_14_4.version
  storage_encrypted = true

  database_name          = "mastodon"
  create_random_password = true
  random_password_length = 30

  vpc_id                = module.strike_witches_vpc.vpc_id
  subnets               = module.strike_witches_vpc.intra_subnets
  create_security_group = true
  allowed_cidr_blocks   = module.strike_witches_vpc.private_subnets_cidr_blocks

  preferred_maintenance_window = "sat:20:00-sat:21:00"
  apply_immediately            = true

  db_parameter_group_name         = aws_db_parameter_group.mastodon.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.mastodon.id

  instance_class = "db.t4g.medium"
  instances = {
    three = {}
    four  = {}
  }
}

resource "aws_security_group" "mastodon_redis" {
  name_prefix = "mastodon-redis"
  vpc_id      = module.strike_witches_vpc.vpc_id

  ingress {
    description = "Allow strike-witches private subnets"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_elasticache_subnet_group" "mastodon" {
  name       = "mastodon"
  subnet_ids = module.strike_witches_vpc.intra_subnets
}

resource "aws_elasticache_parameter_group" "mastodon" {
  name   = "mastodon"
  family = "redis6.x"
}

resource "aws_elasticache_replication_group" "mastodon" {
  replication_group_id = "mastodon"
  description          = "mastodon"
  engine               = "redis"
  engine_version       = "6.x"

  preferred_cache_cluster_azs = slice(module.strike_witches_vpc.azs, 0, 2)
  security_group_ids          = [aws_security_group.mastodon_redis.id]
  subnet_group_name           = aws_elasticache_subnet_group.mastodon.name

  num_cache_clusters         = 2
  multi_az_enabled           = true
  automatic_failover_enabled = true

  node_type = "cache.t4g.small"

  parameter_group_name = aws_elasticache_parameter_group.mastodon.name

  apply_immediately = true
}

resource "aws_s3_bucket" "mastodon" {
  bucket_prefix = "pbzweihander-mastodon"
}

data "aws_iam_policy_document" "mastodon_s3_bucket_policy" {
  statement {
    actions = [
      "s3:GetObject",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "${aws_s3_bucket.mastodon.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_s3_bucket_policy" "mastodon" {
  bucket = aws_s3_bucket.mastodon.bucket
  policy = data.aws_iam_policy_document.mastodon_s3_bucket_policy.json
}

data "aws_iam_policy_document" "mastodon" {
  statement {
    actions = [
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = [
      "${aws_s3_bucket.mastodon.arn}/*"
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "mastodon" {
  name_prefix = "mastodon"
  policy      = data.aws_iam_policy_document.mastodon.json
}

data "aws_iam_policy_document" "mastodon_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.strike_witches_eks.eks_cluster_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.strike_witches_eks.eks_cluster_oidc_provider}:sub"

      values = [
        "system:serviceaccount:${local.mastodon_namespace}:${local.mastodon_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "mastodon" {
  name_prefix        = "mastodon"
  assume_role_policy = data.aws_iam_policy_document.mastodon_assume.json
}

resource "aws_iam_role_policy_attachment" "mastodon" {
  role       = aws_iam_role.mastodon.name
  policy_arn = aws_iam_policy.mastodon.arn
}

resource "random_password" "mastodon_secret_key_base" {
  length = 42
}

resource "random_password" "mastodon_otp_secret" {
  length = 42
}

resource "kubernetes_namespace" "mastodon" {
  provider = kubernetes.strike_witches

  metadata {
    name = local.mastodon_namespace
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubernetes_secret" "mastodon_redis" {
  provider = kubernetes.strike_witches

  depends_on = [
    kubernetes_namespace.mastodon,
  ]

  metadata {
    name      = "mastodon-redis-external"
    namespace = local.mastodon_namespace
  }

  data = {
    redis-password = ""
  }
}

resource "helm_release" "mastodon" {
  provider = helm.strike_witches

  depends_on = [
    kubernetes_namespace.mastodon,
  ]

  chart = local.mastodon_chart_path

  namespace         = local.mastodon_namespace
  name              = "mastodon"
  create_namespace  = false
  dependency_update = true

  wait          = false
  wait_for_jobs = false
  timeout       = 900

  values = [yamlencode({
    image = {
      tag = "v4.0.2"
    }
    mastodon = {
      createAdmin = {
        enabled  = true
        username = "pbzweihander"
        email    = "pbzweihander@gmail.com"
      }
      locale       = "ko"
      local_domain = "pbzweihander.dev"
      web_domain   = local.mastodon_web_domain
      s3 = {
        enabled  = true
        bucket   = aws_s3_bucket.mastodon.bucket
        endpoint = "https://s3.${data.aws_region.current.name}.amazonaws.com"
        hostname = "s3.${data.aws_region.current.name}.amazonaws.com"
        region   = data.aws_region.current.name
      }
      secrets = {
        secret_key_base = random_password.mastodon_secret_key_base.result
        otp_secret      = random_password.mastodon_otp_secret.result
        vapid = {
          private_key = var.mastodon_vapid_private_key
          public_key  = var.mastodon_vapid_public_key
        }
      }
      sidekiq = {
        replicaCount = 2
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name"      = "mastodon"
                      "app.kubernetes.io/instance"  = "mastodon"
                      "app.kubernetes.io/component" = "sidekiq"
                    }
                  }
                  topologyKey = "topology.kubernetes.io/zone"
                }
                weight = 100
              },
            ]
          }
        }
      }
      smtp = {
        from_address = "pbzweihander@gmail.com"
        port         = 465
        server       = "smtp.gmail.com"
        tls          = true
        login        = "pbzweihander@gmail.com"
        password     = var.gmail_smtp_password
      }
      streaming = {
        replicaCount = 1
        service = {
          annotations = {
            "alb.ingress.kubernetes.io/healthcheck-path"        = "/api/v1/streaming/health"
            "alb.ingress.kubernetes.io/target-group-attributes" = "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=300"
          }
        }
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name"      = "mastodon"
                      "app.kubernetes.io/instance"  = "mastodon"
                      "app.kubernetes.io/component" = "streaming"
                    }
                  }
                  topologyKey = "topology.kubernetes.io/zone"
                }
                weight = 100
              },
            ]
          }
        }
      }
      web = {
        replicaCount = 2
        service = {
          annotations = {
            "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
          }
        }
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name"      = "mastodon"
                      "app.kubernetes.io/instance"  = "mastodon"
                      "app.kubernetes.io/component" = "web"
                    }
                  }
                  topologyKey = "topology.kubernetes.io/zone"
                }
                weight = 100
              },
            ]
          }
        }
      }
    }
    ingress = {
      annotations = {
        "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"  = "ip"
        "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/ssl-redirect" = "443"
      }
      hosts = [{
        host  = local.mastodon_web_domain
        paths = [{ path = "/" }]
      }]
      tls              = false
      ingressClassName = "alb"
    }
    elasticsearch = {
      enabled = false
    }
    postgresql = {
      enabled            = false
      postgresqlHostname = module.mastodon_rds.cluster_endpoint
      auth = {
        database = module.mastodon_rds.cluster_database_name
        username = module.mastodon_rds.cluster_master_username
        password = module.mastodon_rds.cluster_master_password
      }
    }
    redis = {
      enabled       = false
      redisHostname = aws_elasticache_replication_group.mastodon.primary_endpoint_address
      auth = {
        existingSecret = kubernetes_secret.mastodon_redis.metadata[0].name
      }
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.mastodon.arn
      }
    }
    # https://github.com/hashicorp/terraform-provider-helm/issues/515#issuecomment-1237328171
    chartHash = local.mastodon_chart_hash
  })]
}
