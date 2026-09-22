s3_endpoint  = "https://s3-oslo.educloud.uio.no"
iam_endpoint = "https://iam.educloud.uio.no:16443"
region       = "region1"

# Admin API endpoint used at plan time to resolve each user's active S3
# credentials. Required.
admin_endpoint = "https://s3-admin.educloud.uio.no:19443"

# Single Vault secret (at <vault_mount>/<admin_vault_path>) holding the Admin
# API credential: admin_user / admin_password.
vault_address    = "https://vault.uio.no"
vault_mount      = "it-usit-bsd-drift"
admin_vault_path = "storage/cloudian/ojd/api-admin"

# Set true if the Admin API uses a self-signed TLS certificate.
admin_insecure_tls = false

# Set to false if your HyperStore release rejects the IAM calls the AWS
# provider makes. See the IAM section of the README.
manage_iam_users    = true
manage_iam_policies = true
