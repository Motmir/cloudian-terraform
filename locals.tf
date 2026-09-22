locals {
  # Every user is one JSON file at groups/<group>/users/<user>.json.
  # The tree on disk is the source of truth; nothing is listed twice.
  user_files = fileset("${path.module}/groups", "*/users/*.json")

  # "uio/users/iti-ops.json" -> "uio/iti-ops".
  # Built by splitting rather than replace(), which interprets a /-wrapped
  # pattern such as "/users/" as a regular expression.
  users = {
    for f in local.user_files :
    "${split("/", f)[0]}/${trimsuffix(basename(f), ".json")}" => jsondecode(file("${path.module}/groups/${f}"))
  }

  # Admin API credential lookup per user. The directory name under groups/ is
  # the default HyperStore group id; a user file may override it with "group_id"
  # when the tree is organised by team rather than by group.
  admin_queries = {
    for key, spec in local.users :
    key => {
      user     = split("/", key)[1]
      group_id = try(spec.group_id, split("/", key)[0])
    }
  }
}
