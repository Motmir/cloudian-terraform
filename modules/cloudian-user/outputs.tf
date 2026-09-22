output "buckets" {
  description = "Names of the buckets managed for this user."
  value       = local.bucket_names
}

output "iam_users" {
  description = "IAM user names managed for this user."
  value       = local.iam_user_names
}

output "iam_access_keys" {
  description = "Generated IAM access keys, keyed by IAM user name."
  sensitive   = true
  value = {
    for k, v in aws_iam_access_key.this : k => {
      access_key = v.id
      secret_key = v.secret
    }
  }
}
