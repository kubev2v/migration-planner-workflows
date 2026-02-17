# =============================================================================
# Makefile for OpenAPI Client Generator
# =============================================================================
# Local testing with act-cli
# =============================================================================

.PHONY: help test test-publish test-verbose test-allowlist test-all setup-secrets clean check-act

# Default target
help:
	@echo "OpenAPI Client Generator - Local Testing"
	@echo ""
	@echo "Usage:"
	@echo "  make setup-secrets   Create .secrets file template"
	@echo "  make test            Run test workflow via act (dry-run mode, no npm publish)"
	@echo "  make test-publish    Run test workflow with actual npm publishing"
	@echo "  make test-verbose   Run test workflow with verbose output"
	@echo "  make test-allowlist Run allowlist validation and authorize logic tests (no Docker)"
	@echo "  make test-all       Run test-allowlist then test (act)"
	@echo "  make clean           Remove generated artifacts"
	@echo "  make check-act       Verify act-cli is installed"
	@echo ""
	@echo "Variables:"
	@echo "  GITHUB_REPOSITORY   Override github.repository context (default: kubev2v/migration-planner-client-generator)"
	@echo "  TEST_NPM_PUBLISH    Set to 'true' to enable npm publishing (default: empty/dry-run)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - act-cli: brew install act (for make test)"
	@echo "  - Docker (or Podman): must be running (for make test)"

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

# Create .secrets file template
setup-secrets:
	@if [ -f .secrets ]; then \
		echo "⚠️  .secrets file already exists. Remove it first to regenerate."; \
	else \
		echo "Creating .secrets file..."; \
		echo '# Secrets for local act-cli testing' > .secrets; \
		echo '# WARNING: Never commit this file!' >> .secrets; \
		echo '' >> .secrets; \
		echo '# npm token for publishing' >> .secrets; \
		echo '# - For dry-run testing: use any fake value' >> .secrets; \
		echo '# - For actual publish testing: use a real npm granular access token' >> .secrets; \
		echo '#   (OIDC/Trusted Publishing does not work locally, so token auth is used as fallback)' >> .secrets; \
		echo 'NPM_TOKEN=fake-token-for-testing' >> .secrets; \
		echo '' >> .secrets; \
		echo "✅ Created .secrets file"; \
		echo ""; \
		echo "Edit .secrets if you need to customize the values."; \
		echo "For actual publish testing, replace NPM_TOKEN with a real token."; \
	fi

# Check if act is installed
check-act:
	@which act > /dev/null 2>&1 || (echo "❌ act-cli is not installed. Run: brew install act" && exit 1)
	@echo "✅ act-cli is installed: $$(act --version)"

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

# Default repository for mocking github.repository context
GITHUB_REPOSITORY ?= kubev2v/migration-planner-client-generator

# Feature toggle for npm publishing (empty = dry-run, "true" = actual publish)
TEST_NPM_PUBLISH ?=

# Common act flags for Docker-in-Docker support
ACT_FLAGS = --secret-file .secrets \
	--bind \
	--container-options "--privileged" \
	--container-daemon-socket /var/run/docker.sock \
	--var GITHUB_REPOSITORY=$(GITHUB_REPOSITORY) \
	--var TEST_NPM_PUBLISH=$(TEST_NPM_PUBLISH) \
	-P ubuntu-latest=catthehacker/ubuntu:act-latest

# Run allowlist and authorize logic tests (no Docker/act)
test-allowlist:
	@echo "🧪 Running allowlist and authorize logic tests..."
	@./tests/validate_allowed_repos.sh
	@./tests/test_authorize_logic.sh
	@echo "✅ test-allowlist passed"

# Run allowlist tests then full act workflow test
test-all: test-allowlist test
	@echo "✅ test-all passed"

# Run test workflow (dry-run mode - no actual publishing)
test: check-act
	@if [ ! -f .secrets ]; then \
		echo "❌ .secrets file not found. Run: make setup-secrets"; \
		exit 1; \
	fi
	@echo "🧪 Running test workflow (dry-run mode)..."
	act push -W .github/workflows/test.yml $(ACT_FLAGS)

# Run test workflow with actual npm publishing (requires real NPM_TOKEN in .secrets)
test-publish: check-act
	@if [ ! -f .secrets ]; then \
		echo "❌ .secrets file not found. Run: make setup-secrets"; \
		exit 1; \
	fi
	@echo "🚀 Running test workflow with npm publishing enabled..."
	@echo "   ⚠️  This will publish and then unpublish to npm!"
	act push -W .github/workflows/test.yml $(ACT_FLAGS) --var TEST_NPM_PUBLISH=true

# Run test workflow with verbose output
test-verbose: check-act
	@if [ ! -f .secrets ]; then \
		echo "❌ .secrets file not found. Run: make setup-secrets"; \
		exit 1; \
	fi
	@echo "🧪 Running test workflow (verbose)..."
	act push -W .github/workflows/test.yml $(ACT_FLAGS) --verbose

# Run with specific container architecture (useful for Apple Silicon)
test-arm64: check-act
	@if [ ! -f .secrets ]; then \
		echo "❌ .secrets file not found. Run: make setup-secrets"; \
		exit 1; \
	fi
	@echo "🧪 Running test workflow (ARM64)..."
	act push -W .github/workflows/test.yml $(ACT_FLAGS) --container-architecture linux/arm64

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Remove generated artifacts
clean:
	@echo "🧹 Cleaning up generated artifacts..."
	rm -rf generated-client/
	rm -rf .act/
	@echo "✅ Cleanup complete"

# Remove secrets file
clean-secrets:
	@echo "🧹 Removing .secrets file..."
	rm -f .secrets
	@echo "✅ Secrets file removed"

# Full cleanup (including secrets)
clean-all: clean clean-secrets
	@echo "✅ Full cleanup complete"
