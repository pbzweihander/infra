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

resource "aws_ses_domain_identity" "yuri_garden" {
  domain = "yuri.garden"
}

resource "cloudflare_record" "yuri_garden_ses_verification" {
  zone_id = data.cloudflare_zone.yuri_garden.id
  name    = "_amazonses"
  type    = "TXT"
  value   = aws_ses_domain_identity.yuri_garden.verification_token
  proxied = false
}

resource "aws_ses_domain_identity_verification" "yuri_garden" {
  domain     = aws_ses_domain_identity.yuri_garden.id
  depends_on = [cloudflare_record.yuri_garden_ses_verification]
}

resource "aws_ses_domain_dkim" "yuri_garden" {
  domain = aws_ses_domain_identity.yuri_garden.domain
}

resource "cloudflare_record" "yuri_garden_ses_dkim" {
  count   = 3
  zone_id = data.cloudflare_zone.yuri_garden.id
  name    = format("%s._domainkey.%s", element(aws_ses_domain_dkim.yuri_garden.dkim_tokens, count.index), aws_ses_domain_identity.yuri_garden.domain)
  type    = "CNAME"
  value   = format("%s.dkim.amazonses.com", element(aws_ses_domain_dkim.yuri_garden.dkim_tokens, count.index))
  proxied = false
}

data "aws_iam_policy_document" "yuri_garden_ses" {
  statement {
    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      aws_ses_domain_identity.yuri_garden.arn,
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "yuri_garden_ses" {
  name_prefix = "yuri-garden-ses-"
  policy      = data.aws_iam_policy_document.yuri_garden_ses.json
}

resource "aws_iam_user" "yuri_garden_ses" {
  name = "yuri-garden-ses"
}

resource "aws_iam_user_policy_attachment" "yuri_garden_ses" {
  user       = aws_iam_user.yuri_garden_ses.name
  policy_arn = aws_iam_policy.yuri_garden_ses.arn
}

resource "aws_iam_access_key" "yuri_garden_ses" {
  user = aws_iam_user.yuri_garden_ses.name
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
  preferred_backup_window      = "19:00-20:00"
  backup_retention_period      = 7

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

resource "aws_acm_certificate" "wildcard_contest_yuri_garden" {
  domain_name       = "*.contest.yuri.garden"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "wildcard_contest_yuri_garden_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_contest_yuri_garden.domain_validation_options : dvo.domain_name => {
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

resource "random_password" "baekyae_contest_jwt_secret" {
  length = 42
}

resource "random_password" "baekyae_contest_postgres_password" {
  length = 42
}

resource "kubectl_manifest" "baekyae_contest" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/yuri_garden/baekyae_contest.yaml",
    {
      jwtSecret        = random_password.baekyae_contest_jwt_secret.result
      misskeyApiKey    = var.yuri_garden_contest_misskey_api_key
      postgresPassword = random_password.baekyae_contest_postgres_password.result
    },
  )
}

resource "random_password" "yurigarden_contest_jwt_secret" {
  length = 42
}

resource "random_password" "yurigarden_contest_postgres_password" {
  length = 42
}

resource "kubectl_manifest" "yurigarden_contest" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/yuri_garden/yurigarden_contest.yaml",
    {
      jwtSecret        = random_password.yurigarden_contest_jwt_secret.result
      misskeyApiKey    = var.yuri_garden_contest_misskey_api_key
      postgresPassword = random_password.yurigarden_contest_postgres_password.result
    },
  )
}

resource "aws_acm_certificate" "outline_yuri_garden" {
  domain_name       = "outline.yuri.garden"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "outline_yuri_garden_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.outline_yuri_garden.domain_validation_options : dvo.domain_name => {
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

resource "random_password" "yuri_garden_outline_rds_password" {
  length  = 42
  special = false
}

resource "random_id" "yuri_garden_outline_secret_key" {
  byte_length = 32
}

resource "random_password" "yuri_garden_outline_utils_secret" {
  length  = 42
  special = false
}

resource "random_password" "yuri_garden_outline_oidc_client_id" {
  length  = 42
  special = false
}

resource "random_password" "yuri_garden_outline_oidc_client_secret" {
  length  = 42
  special = false
}

resource "aws_security_group" "yuri_garden_outline_rds" {
  name   = "yuri-garden-outline-rds"
  vpc_id = module.strike_witches_vpc.vpc_id

  ingress {
    description = "Allow strike-witches private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
  }
}

module "yuri_garden_outline_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.1.0"

  identifier           = "yuri-garden-outline"
  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t4g.small"
  deletion_protection  = true

  apply_immediately = true

  allocated_storage     = 50
  max_allocated_storage = 100

  db_name                     = "outline"
  username                    = "outline"
  port                        = 5432
  manage_master_user_password = false
  password                    = random_password.yuri_garden_outline_rds_password.result

  multi_az               = true
  subnet_ids             = module.strike_witches_vpc.intra_subnets
  vpc_security_group_ids = [aws_security_group.yuri_garden_outline_rds.id]

  create_db_subnet_group    = true
  create_db_parameter_group = true

  maintenance_window       = "sat:20:00-sat:21:00"
  backup_window            = "19:00-20:00"
  backup_retention_period  = 7
  delete_automated_backups = false
}

resource "aws_s3_bucket" "yuri_garden_outline" {
  bucket_prefix = "yuri-garden-outline"
}

data "aws_iam_policy_document" "yuri_garden_outline" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.yuri_garden_outline.arn}",
      "${aws_s3_bucket.yuri_garden_outline.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "yuri_garden_outline" {
  name_prefix = "yuri-garden-outline"
  policy      = data.aws_iam_policy_document.yuri_garden_outline.json
}

data "aws_iam_policy_document" "yuri_garden_outline_assume" {
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
        "system:serviceaccount:yuri-garden:yuri-garden-outline",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "yuri_garden_outline" {
  name_prefix        = "yuri-garden-outline"
  assume_role_policy = data.aws_iam_policy_document.yuri_garden_outline_assume.json
}

resource "aws_iam_role_policy_attachment" "yuri_garden_outline" {
  role       = aws_iam_role.yuri_garden_outline.name
  policy_arn = aws_iam_policy.yuri_garden_outline.arn
}

resource "kubectl_manifest" "yuri_garden_outline" {
  provider = kubectl.strike_witches

  depends_on = [
    kubectl_manifest.yuri_garden_project,
  ]

  yaml_body = templatefile(
    "argocd/yuri_garden/outline.yaml",
    {
      roleArn = aws_iam_role.yuri_garden_outline.arn
      outline = {
        secretKey   = random_id.yuri_garden_outline_secret_key.hex
        utilsSecret = random_password.yuri_garden_outline_utils_secret.result
      }
      database = {
        url = "postgres://${module.yuri_garden_outline_rds.db_instance_username}:${random_password.yuri_garden_outline_rds_password.result}@${module.yuri_garden_outline_rds.db_instance_address}:5432/${module.yuri_garden_outline_rds.db_instance_name}"
      }
      s3 = {
        bucket = aws_s3_bucket.yuri_garden_outline.bucket
      }
      oidc = {
        clientId     = random_password.yuri_garden_outline_oidc_client_id.result
        clientSecret = random_password.yuri_garden_outline_oidc_client_secret.result
      }
      smtp = {
        username = aws_iam_access_key.yuri_garden_ses.id
        password = aws_iam_access_key.yuri_garden_ses.ses_smtp_password_v4
      }
    },
  )
}
