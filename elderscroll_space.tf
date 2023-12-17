data "cloudflare_zone" "elderscrolls_space" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "elderscrolls.space"
}

resource "aws_acm_certificate" "elderscrolls_space" {
  domain_name       = "elderscrolls.space"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "elderscrolls_space_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.elderscrolls_space.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.elderscrolls_space.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "aws_ses_domain_identity" "elderscrolls_space" {
  domain = "elderscrolls.space"
}

resource "cloudflare_record" "elderscrolls_space_ses_verification" {
  zone_id = data.cloudflare_zone.elderscrolls_space.id
  name    = "_amazonses"
  type    = "TXT"
  value   = aws_ses_domain_identity.elderscrolls_space.verification_token
  proxied = false
}

resource "aws_ses_domain_identity_verification" "elderscrolls_space" {
  domain     = aws_ses_domain_identity.elderscrolls_space.id
  depends_on = [cloudflare_record.elderscrolls_space_ses_verification]
}

resource "aws_ses_domain_dkim" "elderscrolls_space" {
  domain = aws_ses_domain_identity.elderscrolls_space.domain
}

resource "cloudflare_record" "elderscrolls_space_ses_dkim" {
  count   = 3
  zone_id = data.cloudflare_zone.elderscrolls_space.id
  name    = format("%s._domainkey.%s", element(aws_ses_domain_dkim.elderscrolls_space.dkim_tokens, count.index), aws_ses_domain_identity.elderscrolls_space.domain)
  type    = "CNAME"
  value   = format("%s.dkim.amazonses.com", element(aws_ses_domain_dkim.elderscrolls_space.dkim_tokens, count.index))
  proxied = false
}

data "aws_iam_policy_document" "elderscrolls_space_ses" {
  statement {
    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      aws_ses_domain_identity.elderscrolls_space.arn,
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "elderscrolls_space_ses" {
  name_prefix = "elderscrolls-space-ses-"
  policy      = data.aws_iam_policy_document.elderscrolls_space_ses.json
}

resource "aws_iam_user" "elderscrolls_space_ses" {
  name = "elderscrolls-space-ses"
}

resource "aws_iam_user_policy_attachment" "elderscrolls_space_ses" {
  user       = aws_iam_user.elderscrolls_space_ses.name
  policy_arn = aws_iam_policy.elderscrolls_space_ses.arn
}

resource "aws_iam_access_key" "elderscrolls_space_ses" {
  user = aws_iam_user.elderscrolls_space_ses.name
}

resource "onepassword_item" "elderscrolls_space_ses" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "elderscrolls-space-ses"
  category = "login"
  username = aws_iam_access_key.elderscrolls_space_ses.id
  password = aws_iam_access_key.elderscrolls_space_ses.ses_smtp_password_v4

  lifecycle {
    ignore_changes = [
      password,
    ]
  }
}

resource "random_password" "elderscrolls_space_misskey_rds" {
  length  = 40
  special = false
}

resource "aws_security_group" "elderscrolls_space_misskey_rds" {
  name   = "elderscrolls-space-misskey-rds"
  vpc_id = module.strike_witches_vpc.vpc_id

  ingress {
    description = "Allow strike-witches private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
  }
}

module "elderscrolls_space_misskey_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.3.0"

  identifier           = "elderscrolls-space-misskey"
  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t4g.small"
  deletion_protection  = true

  apply_immediately = true

  allocated_storage     = 50
  max_allocated_storage = 100

  db_name                     = "misskey"
  username                    = "misskey"
  port                        = 5432
  manage_master_user_password = false
  password                    = random_password.elderscrolls_space_misskey_rds.result

  multi_az               = true
  subnet_ids             = module.strike_witches_vpc.intra_subnets
  vpc_security_group_ids = [aws_security_group.elderscrolls_space_misskey_rds.id]

  create_db_subnet_group    = true
  create_db_parameter_group = true

  maintenance_window       = "sat:20:00-sat:21:00"
  backup_window            = "19:00-20:00"
  backup_retention_period  = 7
  delete_automated_backups = false
}

resource "onepassword_item" "elderscrolls_space_misskey_rds" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "elderscrolls-space-misskey-rds"
  category = "database"
  type     = "postgresql"
  hostname = module.elderscrolls_space_misskey_rds.db_instance_address
  port     = 5432
  database = module.elderscrolls_space_misskey_rds.db_instance_name
  username = module.elderscrolls_space_misskey_rds.db_instance_username
  password = random_password.elderscrolls_space_misskey_rds.result
}

resource "aws_security_group" "elderscrolls_space_misskey_elasticache" {
  name_prefix = "elderscrolls-space-misskey-elasticache-"
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

resource "aws_elasticache_subnet_group" "elderscrolls_space_misskey" {
  name       = "elderscrolls-space-misskey"
  subnet_ids = module.strike_witches_vpc.intra_subnets
}

resource "aws_elasticache_parameter_group" "elderscrolls_space_misskey" {
  name   = "elderscrolls-space-misskey"
  family = "redis6.x"
}

resource "aws_elasticache_replication_group" "elderscrolls_space_misskey" {
  replication_group_id = "elderscrolls-space-misskey"
  description          = "elderscrolls.space"
  engine               = "redis"
  engine_version       = "6.x"

  preferred_cache_cluster_azs = slice(module.strike_witches_vpc.azs, 0, 2)
  security_group_ids          = [aws_security_group.elderscrolls_space_misskey_elasticache.id]
  subnet_group_name           = aws_elasticache_subnet_group.elderscrolls_space_misskey.name

  num_cache_clusters         = 2
  multi_az_enabled           = true
  automatic_failover_enabled = true

  node_type = "cache.t4g.small"

  parameter_group_name = aws_elasticache_parameter_group.elderscrolls_space_misskey.name

  apply_immediately = true
}

resource "onepassword_item" "elderscrolls_space_misskey_elasticache" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "elderscrolls-space-misskey-elasticache"
  category = "database"
  type     = "other"
  hostname = aws_elasticache_replication_group.elderscrolls_space_misskey.primary_endpoint_address
  port     = 6379
  database = ""
  username = ""
  password = ""
}

resource "cloudflare_r2_bucket" "elderscrolls_space" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "elderscrolls-space"
  location   = "APAC"
}

resource "random_password" "elderscrolls_space_meilisearch_master_key" {
  length  = 40
  special = false
}

resource "onepassword_item" "elderscrolls_space_meilisearch" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "elderscrolls-space-meilisearch"
  category = "password"
  password = random_password.elderscrolls_space_meilisearch_master_key.result
}

resource "kubernetes_namespace" "elderscrolls_space" {
  provider = kubernetes.strike_witches

  metadata {
    name = "elderscrolls-space"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
      "secrets-injection"                       = "enabled"
    }
  }
}

resource "kubernetes_secret_v1" "elderscrolls_space_onepassword_service_account" {
  provider = kubernetes.strike_witches

  metadata {
    name      = "onepassword-service-account"
    namespace = kubernetes_namespace.elderscrolls_space.metadata[0].name
  }
  type = "Opaque"
  data = {
    token = var.onepassword_service_account_token_strike_witches
  }
}

resource "kubernetes_secret_v1" "elderscrolls_space_meilisearch_master_key" {
  provider = kubernetes.strike_witches

  metadata {
    name      = "elderscrolls-space-meilisearch-master-key"
    namespace = kubernetes_namespace.elderscrolls_space.metadata[0].name
  }
  type = "Opaque"
  data = {
    MEILI_MASTER_KEY = random_password.elderscrolls_space_meilisearch_master_key.result
  }
}
