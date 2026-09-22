.PHONY: generate init fmt validate plan apply check clean

generate: ## Regenerate per-user provider stubs from the groups/ JSON tree
	python3 scripts/generate_users.py
	terraform fmt >/dev/null

init:
	terraform init

fmt:
	terraform fmt -recursive

validate: generate
	terraform validate

plan: generate
	terraform plan

apply: generate
	terraform apply

## CI guard: fail if the committed stubs are out of sync with groups/
check: generate
	@git diff --exit-code -- 'user_*.tf' zz_generated_outputs.tf \
		|| (echo "\nStubs are stale. Run 'make generate' and commit the result." && exit 1)
	terraform fmt -check -recursive
	terraform validate

clean:
	rm -f user_*.tf zz_generated_outputs.tf
