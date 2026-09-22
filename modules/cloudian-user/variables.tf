variable "spec" {
  description = <<-EOT
    Decoded contents of one groups/<group>/users/<user>.json file.
    See the repository README for the schema.
  EOT
  type        = any
}

variable "manage_iam_users" {
  description = "Create IAM users via Cloudian's IAM-compatible API."
  type        = bool
  default     = true
}

variable "manage_iam_policies" {
  description = "Manage inline IAM user policies via Cloudian's IAM-compatible API."
  type        = bool
  default     = true
}
