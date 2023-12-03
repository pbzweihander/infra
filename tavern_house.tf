data "cloudflare_zone" "tavern_house" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "tavern.house"
}

resource "aws_acm_certificate" "shelf_tavern_house" {
  domain_name       = "shelf.tavern.house"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "shelf_tavern_house_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shelf_tavern_house.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.tavern_house.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "aws_ses_domain_identity" "tavern_house" {
  domain = "tavern.house"
}

resource "cloudflare_record" "tavern_house_ses_verification" {
  zone_id = data.cloudflare_zone.tavern_house.id
  name    = "_amazonses"
  type    = "TXT"
  value   = aws_ses_domain_identity.tavern_house.verification_token
  proxied = false
}

resource "aws_ses_domain_identity_verification" "tavern_house" {
  domain     = aws_ses_domain_identity.tavern_house.id
  depends_on = [cloudflare_record.tavern_house_ses_verification]
}

resource "aws_ses_domain_dkim" "tavern_house" {
  domain = aws_ses_domain_identity.tavern_house.domain
}

resource "cloudflare_record" "tavern_house_ses_dkim" {
  count   = 3
  zone_id = data.cloudflare_zone.tavern_house.id
  name    = format("%s._domainkey.%s", element(aws_ses_domain_dkim.tavern_house.dkim_tokens, count.index), aws_ses_domain_identity.tavern_house.domain)
  type    = "CNAME"
  value   = format("%s.dkim.amazonses.com", element(aws_ses_domain_dkim.tavern_house.dkim_tokens, count.index))
  proxied = false
}

data "aws_iam_policy_document" "tavern_house_ses" {
  statement {
    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      aws_ses_domain_identity.tavern_house.arn,
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "tavern_house_ses" {
  name_prefix = "tavern-house-ses-"
  policy      = data.aws_iam_policy_document.tavern_house_ses.json
}

resource "aws_iam_user" "tavern_house_ses" {
  name = "tavern-house-ses"
}

resource "aws_iam_user_policy_attachment" "tavern_house_ses" {
  user       = aws_iam_user.tavern_house_ses.name
  policy_arn = aws_iam_policy.tavern_house_ses.arn
}

resource "aws_iam_access_key" "tavern_house_ses" {
  user = aws_iam_user.tavern_house_ses.name
}

resource "onepassword_item" "tavern_house_ses" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "tavern-house-ses"
  category = "login"
  username = aws_iam_access_key.tavern_house_ses.id
  password = aws_iam_access_key.tavern_house_ses.ses_smtp_password_v4

  lifecycle {
    ignore_changes = [
      password,
    ]
  }
}

resource "random_password" "tavern_house_bookstack_rds" {
  length  = 40
  special = false
}

resource "aws_security_group" "tavern_house_bookstack_rds" {
  name   = "tavern-house-bookstack-rds"
  vpc_id = module.strike_witches_vpc.vpc_id

  ingress {
    description = "Allow strike-witches private subnets"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = module.strike_witches_vpc.private_subnets_cidr_blocks
  }
}

module "tavern_house_bookstack_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.3.0"

  identifier           = "tavern-house-bookstack"
  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t4g.small"
  deletion_protection  = true

  apply_immediately = true

  allocated_storage     = 50
  max_allocated_storage = 100

  db_name                     = "bookstack"
  username                    = "bookstack"
  port                        = 3306
  manage_master_user_password = false
  password                    = random_password.tavern_house_bookstack_rds.result

  multi_az               = true
  subnet_ids             = module.strike_witches_vpc.intra_subnets
  vpc_security_group_ids = [aws_security_group.tavern_house_bookstack_rds.id]

  create_db_subnet_group    = true
  create_db_parameter_group = true

  maintenance_window       = "sat:20:00-sat:21:00"
  backup_window            = "19:00-20:00"
  backup_retention_period  = 7
  delete_automated_backups = false
}

resource "onepassword_item" "tavern_house_bookstack_rds" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "tavern-house-bookstack-rds"
  category = "database"
  type     = "mysql"
  hostname = module.tavern_house_bookstack_rds.db_instance_address
  port     = 3306
  database = module.tavern_house_bookstack_rds.db_instance_name
  username = module.tavern_house_bookstack_rds.db_instance_username
  password = random_password.tavern_house_bookstack_rds.result
}

resource "random_password" "tavern_house_bookstack_app_key" {
  length  = 42
  special = false
}

resource "onepassword_item" "tavern_house_bookstack_app_key" {
  vault = data.onepassword_vault.strike_witches.uuid

  title    = "tavern-house-bookstack-app-key"
  category = "password"
  password = random_password.tavern_house_bookstack_app_key.result
}

resource "kubernetes_namespace" "tavern_house" {
  provider = kubernetes.strike_witches

  metadata {
    name = "tavern-house"
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
      "secrets-injection"                       = "enabled"
    }
  }
}

resource "kubernetes_secret_v1" "onepassword_service_account" {
  provider = kubernetes.strike_witches

  metadata {
    name      = "onepassword-service-account"
    namespace = kubernetes_namespace.tavern_house.metadata[0].name
  }
  type = "Opaque"
  data = {
    token = var.onepassword_service_account_token_strike_witches
  }
}
