# cloudian-terraform

Declarative management of Cloudian HyperStore buckets, bucket policies,
lifecycle policies and IAM policies using the standard `hashicorp/aws`
Terraform provider pointed at HyperStore's S3- and IAM-compatible endpoints.

Each Cloudian user's S3 credentials are resolved **at plan time, per user,
from the cluster's Admin API** — the same lookup the
[`cloudian-terraform-poc`](../cloudian-terraform-poc) provider does — so keys
rotated in the CMC are picked up automatically and never drift out of sync.
The single Admin API login (Basic auth) is read from Vault. Nothing is
hardcoded.

## Layout

```
groups/
  <team>/
    users/
      <user>.json        <- the only file you hand-edit
modules/
  cloudian-user/         <- turns one user's JSON into resources
scripts/
  generate_users.py      <- generates the per-user provider stubs
user_<team>_<user>.tf   <- GENERATED, do not edit
zz_generated_outputs.tf  <- GENERATED, do not edit
```

One JSON file per user holds everything for that user: its buckets, their
bucket policies, their lifecycle rules, and its IAM users and policies. The
directory under `groups/` is a *team* name for organisation; the user's real
HyperStore *group* id comes from the file's `group_id` key (defaulting to the
team directory name when they match).

### Why the generated stubs exist

In S3 a bucket belongs to the credentials that created it, so each Cloudian
user must be reached through its own `provider "aws"` block. Terraform cannot
create provider blocks with `for_each`, so one small stub per user is generated
mechanically from the JSON tree. You never edit the stubs; run `make generate`
after adding, renaming or deleting a user file and commit the result.

## Prerequisites

- Terraform >= 1.5
- Python 3 (for the generator)
- A Vault token in the environment (`VAULT_TOKEN`, or `~/.vault-token` from
  `vault login`) — used only to read the single Admin API login
- The HyperStore **Admin API** reachable at plan time, with an Admin user that
  can list active user credentials
- HyperStore groups and users **already provisioned**. This repository does not
  create them; see [Scope](#scope)

## Setup

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # set s3_endpoint, iam_endpoint, region, admin_endpoint
export VAULT_TOKEN="$(vault print token)"

make init
make plan
```

`make plan` and `make apply` run the generator first, so the stubs can never
drift from the JSON tree during normal use.

### Vault layout

Vault holds a single KV v2 secret with the Admin API login (Basic auth):

```
<vault_mount>/<admin_vault_path>      # defaults: cloudian/admin
  admin_user     = "sysadmin"
  admin_password = "..."
```

`vault_mount` defaults to `cloudian` and `admin_vault_path` defaults to
`admin`. No per-user secrets are needed: the per-user S3 credentials are
fetched from the Admin API at plan time.

### How per-user credentials are resolved

For every user, `data.http.user_creds` in `providers.tf` calls

```
GET <admin_endpoint>/user/credentials/list/active?userId=<user>&groupId=<group>
```

with the Basic-auth header from the Vault secret, and takes the first entry's
`accessKey` / `secretKey`. `group` is the directory the user's JSON file lives
in under `groups/`, unless the file sets `"group_id"` to override it — the
override is there because the tree is organised by team, not by HyperStore
group. If a user has no active key the plan fails with an index error naming
the user's stub file; give the user an active access key in the CMC.

## Adding a user

1. Ensure the HyperStore user has an active access key in the CMC.
2. Create `groups/<team>/users/<user>.json`, setting `"group_id"` to the
   user's real HyperStore group id if it differs from the team directory name.
3. `make plan`, review, `make apply`.

Creating a new team directory is just creating the directory.

## User file schema

Every field except `buckets[].name` is optional.

```jsonc
{
  "group_id": "uio-it",              // HyperStore group id; default: the team dir name

  "buckets": [
    {
      "name": "iti-ops-apps",
      "versioning": "Enabled",        // or "Suspended"; omit to leave unmanaged

      "policy": { /* S3 bucket policy document, verbatim */ },

      "lifecycle_rules": [
        {
          "id": "expire-logs",
          "status": "Enabled",        // default "Enabled"
          "filter": {
            "prefix": "logs/",        // omit both keys for "whole bucket"
            "tags": { "class": "temp" }
          },
          "expiration": {
            "days": 90                // or "date", or "expired_object_delete_marker"
          },
          "noncurrent_version_expiration": {
            "noncurrent_days": 30,
            "newer_noncurrent_versions": 5
          },
          "transitions": [
            { "days": 30, "storage_class": "GLACIER" }
          ],
          "noncurrent_version_transitions": [
            { "noncurrent_days": 30, "storage_class": "GLACIER" }
          ],
          "abort_incomplete_multipart_upload": {
            "days_after_initiation": 7
          }
        }
      ]
    }
  ],

  "iam_users": [
    {
      "name": "backup-agent",
      "create_access_key": true,      // default false
      "policies": {
        "read-apps": { /* IAM policy document, verbatim */ }
      }
    }
  ]
}
```

`filter` supports `prefix` and `tags`; when both are given they are wrapped in
an `and` block automatically, as S3 requires. Object-size filters are not
exposed because HyperStore does not implement them.

Policy documents are passed through verbatim, so anything HyperStore accepts
can be expressed.

## Scope

**Managed here:** buckets, bucket policies, bucket versioning, lifecycle
configurations, IAM users, inline IAM user policies, IAM access keys.

**Not managed here:** HyperStore groups and users themselves. Those belong to
HyperStore's tenancy model and are created through the Admin API (port 19443),
which is not an AWS API and which the AWS provider cannot speak. Provision them
out of band, then describe their resources here. This repo does *read* the
Admin API, but only for the single credential lookup that resolves each user's
active S3 keys at plan time.

Note that a HyperStore *user* and an *IAM user* are different things: the
HyperStore user owns the buckets; its credentials are fetched from the Admin
API at plan time. IAM users are subordinate identities beneath it.

## IAM caveats

HyperStore implements a subset of the AWS IAM API, and coverage varies between
releases. The AWS provider also makes calls the real IAM service supports but
HyperStore may not — tag listing on IAM users is the usual offender.

Two escape hatches, both in `terraform.tfvars`:

- `manage_iam_users = false` — stop creating IAM user objects, but keep managing
  inline policies against users created elsewhere. Policies attach by name.
- `manage_iam_policies = false` — stop managing IAM entirely; buckets, bucket
  policies and lifecycle rules still work.

Validate against a single non-production user before rolling this out widely.

## State contains secrets

`aws_iam_access_key` writes the generated secret key into Terraform state, the
per-user S3 secrets fetched from the Admin API appear there too, and so does the
Admin API login read from Vault. Use an encrypted remote backend with
restricted access, and never commit state. `*.tfstate*` is gitignored.

No backend is configured in this repo; add a `backend` block in `versions.tf`
for your environment.

## CI

`make check` regenerates the stubs, fails if the committed ones were stale,
then runs `terraform fmt -check` and `terraform validate`.
