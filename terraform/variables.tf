variable "cloudflare_zone_id" {
  description = "CloudFlare Zone ID to update DNS records in"
  default     = "33ada8b88a60fad69983e17596e9d753" # chammock.dev zone
}

variable "domain" {
  description = "Domain name for application. Also used to name all resources"
}
