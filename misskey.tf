locals {
  cloudflare_pbzweihander_social_zone_id = "9284bb947a1a9efa0eaba04b52aee8de"

  misskey_namespace           = "misskey"
  misskey_serviceaccount_name = "misskey"
  misskey_web_domain          = "pbzweihander.social"

  misskey_object_storage_domain = "object.pbzweihander.social"
  misskey_s3_origin_id          = "misskey-s3-origin"

  // https://github.com/hashicorp/terraform-provider-helm/issues/515#issuecomment-1237328171
  misskey_chart_path = "./chart/misskey"
  misskey_chart_hash = md5(join("", [
    for f in fileset(local.misskey_chart_path, "**") :
    filemd5(format("%s/%s", local.misskey_chart_path, f))
  ]))
}

resource "aws_route53_zone" "pbzweihander_social" {
  name = "pbzweihander.social"
}

resource "aws_acm_certificate" "pbzweihander_social" {
  domain_name       = local.misskey_web_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "object_pbzweihander_social_us_east_1" {
  provider = aws.us_east_1

  domain_name       = local.misskey_object_storage_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "pbzweihander_social_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.pbzweihander_social.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = local.cloudflare_pbzweihander_social_zone_id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "cloudflare_record" "object_pbzweihander_social_us_east_1_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.object_pbzweihander_social_us_east_1.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = local.cloudflare_pbzweihander_social_zone_id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  proxied = false
}

resource "random_password" "misskey_rds_master_password" {
  length  = 42
  special = false
}

module "misskey_rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.3.1"

  name                        = "misskey"
  engine                      = data.aws_rds_engine_version.aurora_postgresql_14_6.engine
  engine_version              = data.aws_rds_engine_version.aurora_postgresql_14_6.version
  master_username             = "misskey"
  manage_master_user_password = false
  master_password             = random_password.misskey_rds_master_password.result
  database_name               = "misskey"

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

resource "aws_security_group" "misskey_redis" {
  name_prefix = "misskey-redis-"
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

resource "aws_elasticache_subnet_group" "misskey" {
  name       = "misskey"
  subnet_ids = module.strike_witches_vpc.intra_subnets
}

resource "aws_elasticache_parameter_group" "misskey" {
  name   = "misskey"
  family = "redis6.x"
}

resource "aws_elasticache_replication_group" "misskey" {
  replication_group_id = "misskey"
  description          = "misskey"
  engine               = "redis"
  engine_version       = "6.x"

  preferred_cache_cluster_azs = slice(module.strike_witches_vpc.azs, 0, 2)
  security_group_ids          = [aws_security_group.misskey_redis.id]
  subnet_group_name           = aws_elasticache_subnet_group.misskey.name

  num_cache_clusters         = 2
  multi_az_enabled           = true
  automatic_failover_enabled = true

  node_type = "cache.t4g.small"

  parameter_group_name = aws_elasticache_parameter_group.misskey.name

  apply_immediately = true
}

resource "aws_s3_bucket" "misskey" {
  bucket_prefix = "pbzweihander-misskey-"
}

resource "aws_s3_bucket_ownership_controls" "misskey" {
  bucket = aws_s3_bucket.misskey.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "misskey" {
  bucket = aws_s3_bucket.misskey.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "misskey" {
  depends_on = [
    aws_s3_bucket_ownership_controls.misskey,
    aws_s3_bucket_public_access_block.misskey,
  ]

  bucket = aws_s3_bucket.misskey.id
  acl    = "private"
}

resource "aws_cloudfront_distribution" "misskey" {
  enabled         = true
  is_ipv6_enabled = true

  aliases = [
    local.misskey_object_storage_domain
  ]

  origin {
    origin_id   = local.misskey_s3_origin_id
    domain_name = aws_s3_bucket.misskey.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.identity.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id = local.misskey_s3_origin_id

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.object_pbzweihander_social_us_east_1.arn
    ssl_support_method  = "sni-only"
  }
}

data "aws_iam_policy_document" "misskey_s3_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.misskey.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.misskey.arn]
    }
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.misskey.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "misskey" {
  bucket = aws_s3_bucket.misskey.id
  policy = data.aws_iam_policy_document.misskey_s3_bucket.json
}

resource "cloudflare_record" "object_pbzweihander_social_cname" {
  zone_id = local.cloudflare_pbzweihander_social_zone_id
  type    = "CNAME"
  name    = local.misskey_object_storage_domain
  value   = aws_cloudfront_distribution.misskey.domain_name
  proxied = false
}

data "aws_iam_policy_document" "misskey" {
  statement {
    actions = [
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = [
      "${aws_s3_bucket.misskey.arn}/*"
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "misskey" {
  name_prefix = "misskey-"
  policy      = data.aws_iam_policy_document.misskey.json
}

data "aws_iam_policy_document" "misskey_assume" {
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
        "system:serviceaccount:${local.misskey_namespace}:${local.misskey_serviceaccount_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "misskey" {
  name_prefix        = "misskey-"
  assume_role_policy = data.aws_iam_policy_document.misskey_assume.json
}

resource "aws_iam_role_policy_attachment" "misskey" {
  role       = aws_iam_role.misskey.name
  policy_arn = aws_iam_policy.misskey.arn
}

resource "kubernetes_namespace" "misskey" {
  provider = kubernetes.strike_witches

  metadata {
    name = local.misskey_namespace
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "helm_release" "misskey" {
  provider = helm.strike_witches

  depends_on = [
    kubernetes_namespace.misskey,
  ]

  chart = local.misskey_chart_path

  namespace        = local.misskey_namespace
  name             = "misskey"
  create_namespace = false
  wait             = false

  values = [yamlencode({
    url = "https://${local.misskey_web_domain}"
    web = {
      replicaCount = 2
      image = {
        repository = "ghcr.io/pbzweihander/misskey"
        tag        = "13.13.2-pbzweihander.0"
      }
      resources = {
        requests = {
          cpu    = "300m"
          memory = "2Gi"
        }
        limits = {
          cpu    = "1000m"
          memory = "3Gi"
        }
      }
    }
    ingress = {
      enabled   = true
      className = "alb"
      annotations = {
        "alb.ingress.kubernetes.io/scheme"                  = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"             = "ip"
        "alb.ingress.kubernetes.io/target-group-attributes" = "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=60"
        "alb.ingress.kubernetes.io/listen-ports"            = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/ssl-redirect"            = "443"
      }
      hosts = [{
        host = local.misskey_web_domain
        paths = [{
          path     = "/"
          pathType = "Prefix"
        }]
      }]
      tls = false
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.misskey.arn
      }
    }
    database = {
      host     = module.misskey_rds.cluster_endpoint
      port     = module.misskey_rds.cluster_port
      database = module.misskey_rds.cluster_database_name
      username = module.misskey_rds.cluster_master_username
      password = random_password.misskey_rds_master_password.result
    }
    redis = {
      host     = aws_elasticache_replication_group.misskey.primary_endpoint_address
      password = ""
    }
    meilisearch = {
      host   = "misskey-meilisearch"
      port   = 7700
      apiKey = random_password.misskey_meilisearch_master_key.result
      ssl    = "false"
      index  = "misskey"
    }
    # https://github.com/hashicorp/terraform-provider-helm/issues/515#issuecomment-1237328171
    chartHash = local.misskey_chart_hash
  })]
}

resource "random_password" "misskey_meilisearch_master_key" {
  length = 42
}

resource "helm_release" "misskey_meilisearch" {
  provider = helm.strike_witches

  depends_on = [
    kubernetes_namespace.misskey,
  ]

  repository = "https://meilisearch.github.io/meilisearch-kubernetes"
  chart      = "meilisearch"
  version    = "0.2.2"

  namespace        = local.misskey_namespace
  name             = "misskey-meilisearch"
  create_namespace = false
  wait             = false

  values = [yamlencode({
    environment = {
      MEILI_ENV        = "production"
      MEILI_MASTER_KEY = random_password.misskey_meilisearch_master_key.result
    }
    persistence = {
      enabled      = true
      size         = "50Gi"
      storageClass = "gp3"
    }
  })]
}
