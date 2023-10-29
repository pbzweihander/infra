data "cloudflare_zone" "pbzweihander_dev" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "pbzweihander.dev"
}

data "cloudflare_zone" "witches_dev" {
  account_id = data.cloudflare_accounts.pbzweihander.accounts[0].id
  name       = "witches.dev"
}
