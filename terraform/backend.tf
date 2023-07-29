
terraform {
  backend "remote" {
    hostname     = "chammock.scalr.io"
    organization = "env-v0o0gghiuf44rumsf"

    workspaces {
      prefix = "chammock-dev-"
    }
  }
}
