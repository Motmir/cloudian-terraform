variable "s3_endpoint" {
  description = "Cloudian HyperStore S3 endpoint, e.g. https://s3.example.no"
  type        = string
}

variable "iam_endpoint" {
  description = "Cloudian HyperStore IAM-compatible endpoint, e.g. https://iam.example.no:16443"
  type        = string
}

variable "region" {
  description = <<-EOT
    Cloudian service region name. Must match the region configured in HyperStore
    (often "region1"). Only used for SigV4 signing; no AWS region semantics apply.
  EOT
  type        = string
  default     = "region1"
}

variable "vault_address" {
  description = "Vault server address. Falls back to the VAULT_ADDR environment variable when null."
  type        = string
  default     = "https://vault.uio.no"
}

variable "vault_mount" {
  description = "Vault KV v2 mount holding the Cloudian user credentials."
  type        = string
  default     = "cloudian"
}

variable "admin_vault_path" {
  description = "Path of the single Vault secret holding the Admin API credential (admin_user / admin_password), relative to vault_mount."
  type        = string
  default     = "admin"
}

variable "admin_endpoint" {
  description = "Cloudian HyperStore Admin API endpoint, e.g. https://s3-admin.example.no:19443. Used at plan time to resolve each user's active S3 credentials."
  type        = string
}

variable "admin_insecure_tls" {
  description = "Skip TLS certificate verification on Admin API calls. Set true for a self-signed Admin API certificate."
  type        = bool
  default     = false
}

variable "manage_iam_users" {
  description = <<-EOT
    Create IAM users via Cloudian's IAM-compatible API. Disable if your HyperStore
    release rejects the tagging calls the AWS provider makes against IAM users;
    policies can still be managed against pre-existing users.
  EOT
  type        = bool
  default     = true
}

variable "manage_iam_policies" {
  description = "Manage inline IAM user policies via Cloudian's IAM-compatible API."
  type        = bool
  default     = true
}
