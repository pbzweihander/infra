variable "gmail_smtp_password" {
  type      = string
  sensitive = true
}

variable "mastodon_vapid_private_key" {
  type      = string
  sensitive = true
}

variable "mastodon_vapid_public_key" {
  type      = string
  sensitive = true
}
