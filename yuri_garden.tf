data "cloudflare_zone" "yuri_garden" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "yuri.garden"
}

resource "aws_acm_certificate" "yuri_garden" {
  domain_name       = "yuri.garden"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "yuri_garden_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.yuri_garden.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.yuri_garden.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "random_password" "yuri_garden_rds_master_password" {
  length  = 42
  special = false
}

module "yuri_garden_rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.3.1"

  name                        = "yuri-garden"
  engine                      = data.aws_rds_engine_version.aurora_postgresql_14_6.engine
  engine_version              = data.aws_rds_engine_version.aurora_postgresql_14_6.version
  master_username             = "yurigarden"
  manage_master_user_password = false
  master_password             = random_password.yuri_garden_rds_master_password.result
  database_name               = "yurigarden"

  apply_immediately = true

  vpc_id  = module.strike_witches_vpc.vpc_id
  subnets = module.strike_witches_vpc.intra_subnets
  security_group_rules = {
    ingress = {
      cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
    }
  }

  preferred_maintenance_window = "sat:20:00-sat:21:00"

  skip_final_snapshot = true

  create_security_group             = true
  create_db_subnet_group            = true
  create_db_parameter_group         = true
  db_parameter_group_family         = "aurora-postgresql14"
  create_db_cluster_parameter_group = true
  db_cluster_parameter_group_family = "aurora-postgresql14"

  instance_class = "db.t4g.medium"
  instances = {
    1 = {}
  }
}

resource "aws_security_group" "yuri_garden_redis" {
  name_prefix = "yuri-garden-redis-"
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

resource "aws_elasticache_subnet_group" "yuri_garden" {
  name       = "yuri-garden"
  subnet_ids = module.strike_witches_vpc.intra_subnets
}

resource "aws_elasticache_parameter_group" "yuri_garden" {
  name   = "yuri-garden"
  family = "redis6.x"
}

resource "aws_elasticache_replication_group" "yuri_garden" {
  replication_group_id = "yuri-garden"
  description          = "yuri.garden"
  engine               = "redis"
  engine_version       = "6.x"

  preferred_cache_cluster_azs = slice(module.strike_witches_vpc.azs, 0, 2)
  security_group_ids          = [aws_security_group.yuri_garden_redis.id]
  subnet_group_name           = aws_elasticache_subnet_group.yuri_garden.name

  num_cache_clusters         = 2
  multi_az_enabled           = true
  automatic_failover_enabled = true

  node_type = "cache.t4g.medium"

  parameter_group_name = aws_elasticache_parameter_group.yuri_garden.name

  apply_immediately = true
}

resource "cloudflare_r2_bucket" "yuri_garden" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "yuri-garden"
  location   = "APAC"
}

resource "kubernetes_namespace" "yuri_garden" {
  provider = kubernetes.strike_witches

  metadata {
    name = "yuri-garden"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubectl_manifest" "yuri_garden_project" {
  provider = kubectl.strike_witches

  depends_on = [
    kubernetes_namespace.yuri_garden,
  ]

  yaml_body = file("argocd/yuri_garden/project.yaml")
}

resource "random_password" "yuri_garden_meilisearch_master_key" {
  length = 42
}

resource "kubectl_manifest" "yuri_garden_meilisearch" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/yuri_garden/meilisearch.yaml",
    {
      master_key = random_password.yuri_garden_meilisearch_master_key.result
    },
  )
}

resource "kubectl_manifest" "yuri_garden_misskey" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/yuri_garden/misskey.yaml",
    {
      database = {
        host     = module.yuri_garden_rds.cluster_endpoint
        port     = module.yuri_garden_rds.cluster_port
        database = module.yuri_garden_rds.cluster_database_name
        username = module.yuri_garden_rds.cluster_master_username
        password = random_password.yuri_garden_rds_master_password.result
      }
      redis = {
        host     = aws_elasticache_replication_group.yuri_garden.primary_endpoint_address
        password = ""
      }
      meilisearch = {
        apiKey = random_password.yuri_garden_meilisearch_master_key.result
      }
    },
  )
}