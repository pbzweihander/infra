resource "aws_acm_certificate" "aquarium_yuri_garden" {
  domain_name       = "aquarium.yuri.garden"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "aquarium_yuri_garden_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.aquarium_yuri_garden.domain_validation_options : dvo.domain_name => {
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

resource "random_password" "aquarium_yuri_garden_rds_password" {
  length  = 42
  special = false
}

resource "aws_security_group" "aquarium_yuri_garden_rds" {
  name   = "aquarium-yuri-garden-rds"
  vpc_id = module.strike_witches_vpc.vpc_id

  ingress {
    description = "Allow strike-witches private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
  }
}

module "aquarium_yuri_garden_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.1.0"

  identifier           = "aquarium-yuri-garden"
  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t4g.small"
  deletion_protection  = true

  apply_immediately = true

  allocated_storage     = 50
  max_allocated_storage = 100

  db_name                     = "aquarium"
  username                    = "aquarium"
  port                        = 5432
  manage_master_user_password = false
  password                    = random_password.aquarium_yuri_garden_rds_password.result

  multi_az               = true
  subnet_ids             = module.strike_witches_vpc.intra_subnets
  vpc_security_group_ids = [aws_security_group.aquarium_yuri_garden_rds.id]

  create_db_subnet_group    = true
  create_db_parameter_group = true

  maintenance_window = "sat:20:00-sat:21:00"

  skip_final_snapshot = true
}

resource "cloudflare_r2_bucket" "aquarium_yuri_garden" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "aquarium-yuri-garden"
  location   = "APAC"
}

resource "kubernetes_namespace" "aquarium_yuri_garden" {
  provider = kubernetes.strike_witches

  metadata {
    name = "aquarium-yuri-garden"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubectl_manifest" "aquarium_yuri_garden_project" {
  provider = kubectl.strike_witches

  depends_on = [
    kubernetes_namespace.aquarium_yuri_garden,
  ]

  yaml_body = file("argocd/aquarium_yuri_garden/project.yaml")
}

resource "random_password" "aquarium_yuri_garden_secret_key_base" {
  length  = 42
  special = false
}

resource "random_password" "aquarium_yuri_garden_otp_secret" {
  length  = 42
  special = false
}

resource "random_password" "aquarium_yuri_garden_redis_password" {
  length  = 42
  special = false
}

resource "kubectl_manifest" "aquarium_yuri_garden_mastodon" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.aquarium_yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/aquarium_yuri_garden/mastodon.yaml",
    {
      r2 = {
        access_key    = var.aquarium_yuri_garden_r2_access_key
        access_secret = var.aquarium_yuri_garden_r2_access_secret
        endpoint      = var.aquarium_yuri_garden_r2_endpoint
      }
      secrets = {
        secret_key_base = random_password.aquarium_yuri_garden_secret_key_base.result
        otp_secret      = random_password.aquarium_yuri_garden_otp_secret.result
        vapid = {
          private_key = var.aquarium_yuri_garden_vapid_private_key
          public_key  = var.aquarium_yuri_garden_vapid_public_key
        }
      }
      smtp = {
        login    = var.aquarium_yuri_garden_smtp_login
        password = var.aquarium_yuri_garden_smtp_password
      }
      database = {
        host     = module.aquarium_yuri_garden_rds.db_instance_address
        database = module.aquarium_yuri_garden_rds.db_instance_name
        username = module.aquarium_yuri_garden_rds.db_instance_username
        password = random_password.aquarium_yuri_garden_rds_password.result
      }
      redis = {
        password = random_password.aquarium_yuri_garden_redis_password.result
      }
    },
  )
}
