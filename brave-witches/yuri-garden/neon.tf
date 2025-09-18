resource "neon_project" "this" {
  name      = "yuri-garden"
  org_id    = "org-wild-sea-49667236"
  region_id = "aws-ap-southeast-1"
  branch = {
    name = "main"
    endpoint = {
      min_cu          = 1
      max_cu          = 7
      suspend_timeout = 300
    }
  }

  lifecycle {
    ignore_changes = [
      branch,
    ]
  }
}

resource "neon_role" "this" {
  name       = "yuri-garden"
  project_id = neon_project.this.id
  branch_id  = neon_project.this.branch.id
}

resource "neon_database" "misskey" {
  name       = "misskey"
  project_id = neon_project.this.id
  branch_id  = neon_project.this.branch.id
  owner_name = neon_role.this.name
}
