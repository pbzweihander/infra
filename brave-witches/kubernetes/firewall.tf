resource "vultr_firewall_rule" "v4_http" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "80"
  notes             = "http"
}

resource "vultr_firewall_rule" "v4_https" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "443"
  notes             = "https"
}

resource "vultr_firewall_rule" "v6_http" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "80"
  notes             = "http"
}

resource "vultr_firewall_rule" "v6_https" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "443"
  notes             = "https"
}

resource "vultr_firewall_rule" "v4_mumble_tcp" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "30738"
  notes             = "mumble"
}

resource "vultr_firewall_rule" "v4_mumble_udp" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "30738"
  notes             = "mumble"
}

resource "vultr_firewall_rule" "v6_mumble_tcp" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "tcp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "30738"
  notes             = "mumble"
}

resource "vultr_firewall_rule" "v6_mumble_udp" {
  firewall_group_id = vultr_kubernetes.this.firewall_group_id
  protocol          = "udp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "30738"
  notes             = "mumble"
}
