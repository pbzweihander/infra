data "aws_rds_engine_version" "aurora_postgresql_14_5" {
  engine  = "aurora-postgresql"
  version = "14.5"
}

data "aws_rds_engine_version" "aurora_postgresql_14_9" {
  engine  = "aurora-postgresql"
  version = "14.9"
}
