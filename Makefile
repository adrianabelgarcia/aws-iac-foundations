SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ROOTS      := bootstrap github-oidc
MODULES    := modules/tags modules/vpc
TF_DIRS    := $(ROOTS) $(MODULES)
POLICY_DIR := policies

.PHONY: help fmt fmt-check init validate lint checkov test policy-test lock check clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-12s %s\n", $$1, $$2}'

fmt: ## Format all Terraform files in place
	terraform fmt -recursive

fmt-check: ## Fail when any Terraform file is not formatted
	terraform fmt -check -recursive -diff

init: ## Initialise every root and module without a backend (offline validation only)
	@for dir in $(TF_DIRS); do \
		echo "==> init $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false -no-color >/dev/null || exit 1; \
	done

validate: init ## Validate every root and module
	@for dir in $(TF_DIRS); do \
		echo "==> validate $$dir"; \
		terraform -chdir=$$dir validate -no-color || exit 1; \
	done

lint: ## Run tflint (aws ruleset) recursively
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

checkov: ## Run checkov over the repository (hard fail)
	checkov -d . --framework terraform --config-file .checkov.yaml

test: ## Run terraform test for every module (no AWS credentials needed)
	@for dir in $(MODULES); do \
		echo "==> test $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false -no-color >/dev/null || exit 1; \
		terraform -chdir=$$dir test -no-color || exit 1; \
	done

policy-test: ## Run OPA unit tests, then check the compliant and violating plan fixtures
	opa test -v $(POLICY_DIR)/
	conftest test $(POLICY_DIR)/fixtures/compliant/plan.json --policy $(POLICY_DIR) --all-namespaces --no-color
	@if conftest test $(POLICY_DIR)/fixtures/violations/plan.json --policy $(POLICY_DIR) --all-namespaces --no-color >/dev/null 2>&1; then \
		echo "violations fixture must fail policy checks"; exit 1; \
	fi

lock: ## Regenerate provider lock files for roots (linux_amd64 and darwin_arm64)
	@for dir in $(ROOTS); do \
		terraform -chdir=$$dir init -backend=false -input=false -no-color >/dev/null && \
		terraform -chdir=$$dir providers lock -platform=linux_amd64 -platform=darwin_arm64 || exit 1; \
	done

check: fmt-check validate lint checkov test policy-test ## Run every check that CI runs

clean: ## Remove local .terraform directories
	find . -type d -name .terraform -prune -exec rm -rf {} +
