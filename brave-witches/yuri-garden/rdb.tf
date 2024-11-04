resource "vultr_database" "misskey_202411_1" {
  label = "yuri-garden-misskey-202411-1"

  region = "icn"

  database_engine         = "pg"
  database_engine_version = "16"

  plan = "vultr-dbaas-startup-cc-hp-amd-2-80-2"

  cluster_time_zone = "Asia/Seoul"
  maintenance_dow   = "tuesday"
  maintenance_time  = "03:00"

  vpc_id = "4815929c-f67f-4551-98f2-ff944276db72"
}

resource "vultr_database_replica" "misskey_202411_1_0" {
  label       = "yuri-garden-misskey-202411-1-0"
  database_id = vultr_database.misskey_202411_1.id
  region      = "icn"
}

resource "vultr_database_replica" "misskey_202411_1_1" {
  label       = "yuri-garden-misskey-202411-1-1"
  database_id = vultr_database.misskey_202411_1.id
  region      = "icn"
}
