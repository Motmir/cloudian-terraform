provider "vault" {
  address = var.vault_address
}

# One Admin API credential, read once at plan time.
data "vault_kv_secret_v2" "admin" {
  mount = var.vault_mount
  name  = var.admin_vault_path
}

# One Admin API credential lookup per user, resolved at plan time so the
# generated per-user provider aliases can reference the returned keys
# directly. The lookup reads each user's active S3 credentials from the
# cluster, so keys rotated in the CMC are picked up on the next plan instead of
# drifting out of sync with a stored copy.
data "http" "user_creds" {
  for_each = local.admin_queries

  url = "${var.admin_endpoint}/user/credentials/list/active?userId=${urlencode(each.value.user)}&groupId=${urlencode(each.value.group_id)}"

  request_headers = {
    Authorization = "Basic ${base64encode("${data.vault_kv_secret_v2.admin.data.admin_user}:${data.vault_kv_secret_v2.admin.data.admin_password}")}"
  }

  insecure = var.admin_insecure_tls
}
