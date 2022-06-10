.DEFAULT_GOAL:=help
SHELL:=/bin/bash

.PHONY: help build test apply plan infra_apply infra_plan infra_runtest

build: ## Build the terraform packages
	bazel build //...

test: ## Runs the tests
	bazel test //...

infra_destroy: ## Destroy the Terraform deployment
	bazel run //tfinfra:primary.destroy
	bazel run //tfinfra:secondary.destroy

infra_apply: ## Apply the Terraform from the Plan
	bazel run //tfinfra:primary.apply
	bazel run //tfinfra:secondary.apply

infra_plan: ## Run `plan` on the infrastructure
	bazel run //tfinfra:primary.plan
	bazel run //tfinfra:secondary.plan

infra_runtest: ## Run `plan` on the infrastructure
	bazel run //tfinfra:primary_runtest

apply: ## Run `apply` on the blueprint
	bazel run //tfblueprint:deploy.apply

destroy: ## Run `destroy` on the blueprint
	bazel run //tfblueprint:deploy.destroy

show : ## Show the terraform plan as JSON
	bazel run //tfblueprint:deploy.show
	jq '.' .bazel/tfblueprint/deploy/tfplan.json

output : ## Run `output` on the blueprint
	bazel run //tfblueprint:deploy.output
	jq '.' .bazel/tfblueprint/deploy/output.json

plan : ## Run `plan` on the blueprint
	bazel run //tfblueprint:deploy.plan

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)