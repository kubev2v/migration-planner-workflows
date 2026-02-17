# =============================================================================
# Makefile for OpenAPI Client Generator
# =============================================================================
# Local testing with act-cli
# =============================================================================

.PHONY: help test test-verbose clean check-act

# Default target
help:
	@echo "OpenAPI Client Generator - Local Testing"
	@echo ""
	@echo "Usage:"
	@echo "  make test            Run test workflow via act (dry-run mode, no npm publish)"
	@echo "  make test-verbose   Run test workflow with verbose output"
	@echo "  make clean           Remove generated artifacts"
	@echo "  make check-act       Verify act-cli is installed"
	@echo ""
	@echo "Variables:"
	@echo "  GITHUB_REPOSITORY   Override github.repository context (default: kubev2v/migration-planner-client-generator)"
	@echo ""
	@echo "Note: npm publishing requires OIDC Trusted Publishing and only works in CI (GitHub Actions)."
	@echo "      Local testing is limited to dry-run mode."
	@echo ""
	@echo "Prerequisites:"
	@echo "  - act-cli: brew install act (for make test)"
	@echo "  - Docker (or Podman): must be running (for make test)"

# Check if act is installed
check-act:
	@which act > /dev/null 2>&1 || (echo "❌ act-cli is not installed. Run: brew install act" && exit 1)
	@echo "✅ act-cli is installed: $$(act --version)"

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

# Default repository for mocking github.repository context
GITHUB_REPOSITORY ?= kubev2v/migration-planner-client-generator

# Common act flags for Docker-in-Docker support
ACT_FLAGS = --bind \
	--container-options "--privileged" \
	--container-daemon-socket /var/run/docker.sock \
	--env GITHUB_REPOSITORY=$(GITHUB_REPOSITORY) \
	-P ubuntu-latest=catthehacker/ubuntu:act-latest

# Run test workflow (dry-run mode - no actual publishing)
test: check-act
	@echo "🧪 Running test workflow (dry-run mode)..."
	act push -W .github/workflows/test.yml $(ACT_FLAGS)

# Run test workflow with verbose output
test-verbose: check-act
	@echo "🧪 Running test workflow (verbose)..."
	act push -W .github/workflows/test.yml $(ACT_FLAGS) --verbose

# Run with specific container architecture (useful for Apple Silicon)
test-arm64: check-act
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
