terraform {
  cloud {
    organization = "env-v0o0gghiuf44rumsf"
    hostname = "chammock.scalr.io"

    workspaces {
      name = "chammock-dev"
    }
  }
}