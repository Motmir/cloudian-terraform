locals {
  bucket_list = try(var.spec.buckets, [])

  # Index by name rather than building a map of bucket objects. Bucket entries
  # have different shapes (some carry a policy, some lifecycle rules, some
  # neither) and Terraform cannot unify those into a single collection type.
  # Indirecting through a map(number) keeps every collection homogeneous and
  # lets us reach the raw, untyped JSON via local.bucket_list[...].
  bucket_index = { for i, b in local.bucket_list : b.name => i }
  bucket_names = keys(local.bucket_index)

  versioned_buckets = [
    for n in local.bucket_names : n
    if try(local.bucket_list[local.bucket_index[n]].versioning, null) != null
  ]

  policied_buckets = [
    for n in local.bucket_names : n
    if try(local.bucket_list[local.bucket_index[n]].policy, null) != null
  ]

  lifecycled_buckets = [
    for n in local.bucket_names : n
    if length(try(local.bucket_list[local.bucket_index[n]].lifecycle_rules, [])) > 0
  ]

  iam_user_list  = try(var.spec.iam_users, [])
  iam_user_index = { for i, u in local.iam_user_list : u.name => i }
  iam_user_names = keys(local.iam_user_index)

  # jsonencode the document here so every value in the map is a string.
  iam_user_policies = {
    for item in flatten([
      for u in local.iam_user_list : [
        for pname, doc in try(u.policies, {}) : {
          key      = "${u.name}:${pname}"
          user     = u.name
          name     = pname
          document = jsonencode(doc)
        }
      ]
    ]) : item.key => item
  }

  access_key_users = [
    for n in local.iam_user_names : n
    if try(local.iam_user_list[local.iam_user_index[n]].create_access_key, false)
  ]
}

resource "aws_s3_bucket" "this" {
  for_each = toset(local.bucket_names)

  bucket = each.key
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = toset(local.versioned_buckets)

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = local.bucket_list[local.bucket_index[each.key]].versioning
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = toset(local.policied_buckets)

  bucket = aws_s3_bucket.this[each.key].id
  policy = jsonencode(local.bucket_list[local.bucket_index[each.key]].policy)
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = toset(local.lifecycled_buckets)

  bucket = aws_s3_bucket.this[each.key].id

  dynamic "rule" {
    for_each = local.bucket_list[local.bucket_index[each.key]].lifecycle_rules

    content {
      id     = rule.value.id
      status = try(rule.value.status, "Enabled")

      # An empty filter block matches every object in the bucket.
      dynamic "filter" {
        for_each = [try(rule.value.filter, {})]

        content {
          prefix = length(try(filter.value.tags, {})) == 0 ? try(filter.value.prefix, null) : null

          # S3 requires prefix+tag combinations to be wrapped in `and`.
          dynamic "and" {
            for_each = length(try(filter.value.tags, {})) > 0 ? [1] : []

            content {
              prefix = try(filter.value.prefix, null)
              tags   = filter.value.tags
            }
          }
        }
      }

      dynamic "expiration" {
        for_each = try(rule.value.expiration, null) != null ? [rule.value.expiration] : []

        content {
          days                         = try(expiration.value.days, null)
          date                         = try(expiration.value.date, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration, null) != null ? [rule.value.noncurrent_version_expiration] : []

        content {
          noncurrent_days           = try(noncurrent_version_expiration.value.noncurrent_days, null)
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
        }
      }

      dynamic "transition" {
        for_each = try(rule.value.transitions, [])

        content {
          days          = try(transition.value.days, null)
          date          = try(transition.value.date, null)
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = try(rule.value.noncurrent_version_transitions, [])

        content {
          noncurrent_days = try(noncurrent_version_transition.value.noncurrent_days, null)
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_upload, null) != null ? [rule.value.abort_incomplete_multipart_upload] : []

        content {
          days_after_initiation = abort_incomplete_multipart_upload.value.days_after_initiation
        }
      }
    }
  }

  # Noncurrent-version rules are only meaningful once versioning is on.
  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_iam_user" "this" {
  for_each = var.manage_iam_users ? toset(local.iam_user_names) : toset([])

  name = each.key
}

resource "aws_iam_user_policy" "this" {
  for_each = var.manage_iam_policies ? local.iam_user_policies : {}

  name = each.value.name
  # Attach by name so policies can target pre-existing IAM users when
  # manage_iam_users is false.
  user   = var.manage_iam_users ? aws_iam_user.this[each.value.user].name : each.value.user
  policy = each.value.document
}

resource "aws_iam_access_key" "this" {
  for_each = var.manage_iam_users ? toset(local.access_key_users) : toset([])

  user = aws_iam_user.this[each.key].name
}
