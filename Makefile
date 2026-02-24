# color-deploy — run from this dir. Set PROJECT_SLUG, LIVE_DOMAIN, STAGING_DOMAIN in .env.
SHELL := /bin/bash
COLORS := blue green yellow
export PATH := $(CURDIR)/.bin:$(PATH)

ifneq (,$(wildcard .env))
  include .env
  export
endif

SSH_KEY := $(shell cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null)
TF_VAR_SSH := $(if $(SSH_KEY),-var "ssh_public_key=$(SSH_KEY)",)

.PHONY: init install-deps deploy-% plan-% destroy-% output-%
# Ensure terraform in PATH (either .bin or system)
install-deps:
	@command -v terraform >/dev/null 2>&1 || ./scripts/install-terraform.sh

init: install-deps
	@cd terraform && terraform init

deploy-%:
	@echo ">>> Deploy $* (project: $(PROJECT_SLUG)) <<<"
	./scripts/apply-stack.sh $* apply -auto-approve $(TF_VAR_SSH)
	@./scripts/update-ssh-config.sh $*

plan-%:
	./scripts/apply-stack.sh $* plan $(TF_VAR_SSH)

destroy-%:
	./scripts/check-prod-not-pointing-to.sh $* && ./scripts/apply-stack.sh $* destroy -auto-approve

output-%:
	./scripts/apply-stack.sh $* output

.PHONY: prod-point-% staging-point-%
prod-point-%:
	@echo ">>> Point prod at $* <<<"
	./scripts/flip-traffic.sh $$(./scripts/get-deployment-ip.sh $*)

staging-point-%:
	@./scripts/point-domain.sh $(STAGING_DOMAIN) $$(./scripts/get-deployment-ip.sh $*)

.PHONY: setup-staging-% setup-prod-%
setup-staging-%:
	./setup.sh $* staging
setup-prod-%:
	./setup.sh $* live

.PHONY: clone-app-%
clone-app-%:
	@./scripts/clone-app.sh $* $(BRANCH)

.PHONY: which-prod ssh-config-% ssh-config diagnose-% validate-% status help
which-prod:
	@./scripts/which-prod.sh
ssh-config-%:
	@./scripts/update-ssh-config.sh $*
ssh-config:
	@for c in $(COLORS); do ./scripts/get-deployment-ip.sh $$c >/dev/null 2>&1 && ./scripts/update-ssh-config.sh $$c || true; done

diagnose-%:
	@./scripts/diagnose-caddy.sh $*

validate-%:
	@./scripts/validate-https.sh $* staging

status:
	@echo ">>> Status <<<"
	@for c in $(COLORS); do ip=$$(./scripts/get-deployment-ip.sh $$c 2>/dev/null) || ip="<not deployed>"; echo "  $$c: $$ip"; done
	@echo "  LIVE_DOMAIN=$(LIVE_DOMAIN) STAGING_DOMAIN=$(STAGING_DOMAIN)"

help:
	@echo "init, deploy-<color>, plan-<color>, destroy-<color>, output-<color>, setup-staging-<color>, setup-prod-<color>, prod-point-<color>, staging-point-<color>, which-prod, ssh-config-<color>, diagnose-<color>, validate-<color>, clone-app-<color>, status"
