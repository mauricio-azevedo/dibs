# Entry point for every build step. CI runs the same targets, so green here is green there.
# `make` alone lists them.

.DEFAULT_GOAL := help
.NOTPARALLEL:
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

MVN := ./mvnw -B -ntp
JAVA_VERSION := $(shell cat .java-version)
IMAGE ?= dibs:$(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
API_BASE ?= main
ALLOW_BREAKING ?= 0
OASDIFF := tufin/oasdiff:v1.35.0
REDOCLY := redocly/cli:2.72.1
TRIVY := aquasec/trivy:0.76.1
# The severity floor for `audit`. Raise it on the target, never skip, when an advisory has no fix yet.
AUDIT_SEVERITY ?= UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL

## Local

.env: .env.example
	cp $< $@

dev: .env ## Postgres in Docker, the app on this JVM. Ctrl+C stops the app, `make down` the rest
	docker compose up -d --wait postgres
	set -a && source .env && set +a && $(MVN) spring-boot:run

down: .env ## Stop and remove everything `dev` started, data included
	docker compose down -v --remove-orphans

## Gate. Each target only verifies; `check` runs them all

check: fmt-check lint typecheck test build audit api-lint api-diff ## The whole gate, same as CI

fmt: ## Rewrite sources into the format fmt-check expects
	$(MVN) spotless:apply

fmt-check: ## Spotless with google-java-format
	$(MVN) spotless:check

lint: ## Checkstyle, the rules in config/checkstyle.xml
	$(MVN) checkstyle:check

typecheck: ## javac -Xlint:all -Werror over main and test sources
	$(MVN) test-compile

test-unit: ## *Test classes: no Spring context, no Docker, seconds. The TDD loop
	$(MVN) test

test: ## test-unit plus *IT classes against Testcontainers. Needs Docker
	$(MVN) verify

audit: build ## Fail on a known vulnerability in the Java dependencies inside the image (Trivy)
	docker save $(IMAGE) -o target/image.tar
	docker run --rm -v trivy-cache:/root/.cache/ -v "$(CURDIR)/target:/work:ro" $(TRIVY) image --input /work/image.tar \
	  --scanners vuln --pkg-types library --severity $(AUDIT_SEVERITY) --exit-code 1 --no-progress

build: ## Build the image from the Dockerfile; fail if its JRE is not .java-version
	$(MVN) package -DskipTests
	docker build --quiet -t $(IMAGE) .
	@actual=$$(docker run --rm --entrypoint java $(IMAGE) -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p'); \
	if [ "$$actual" != "$(JAVA_VERSION)" ]; then echo "image runs JDK $$actual; .java-version says $(JAVA_VERSION)"; exit 1; fi; \
	echo "built $(IMAGE) on JDK $(JAVA_VERSION)"

api-lint: ## Fail on an invalid docs/openapi.yaml (Redocly, rules in config/redocly.yaml)
	docker run --rm -v "$(CURDIR):/work:ro" $(REDOCLY) lint --config /work/config/redocly.yaml /work/docs/openapi.yaml

api-diff: ## Fail on a breaking change to docs/openapi.yaml against origin/main (API_BASE), unless ALLOW_BREAKING=1
	@if ! git fetch -q origin $(API_BASE) 2>/dev/null; then echo "api-diff: no origin/$(API_BASE) to compare against; skipped"; exit 0; fi; \
	mkdir -p target && git show FETCH_HEAD:docs/openapi.yaml > target/openapi-base.yaml; \
	if [ "$(ALLOW_BREAKING)" = "1" ]; then fail=""; else fail="--fail-on ERR"; fi; \
	docker run --rm -v "$(CURDIR):/work:ro" $(OASDIFF) breaking $$fail /work/target/openapi-base.yaml /work/docs/openapi.yaml

help: ## List targets
	@awk 'BEGIN {FS = ":.*## "} /^## / {printf "\n%s\n", substr($$0, 4)} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: dev down check fmt fmt-check lint typecheck test-unit test audit build api-lint api-diff help
