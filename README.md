# OpenAPI Client Generator

A repository providing a reusable GitHub Actions workflow for generating and publishing OpenAPI clients to npm.

## Overview

This repository contains a [reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows) that can be called from other repositories to generate TypeScript clients from OpenAPI specifications and publish them to npm.

### Features

- **Reusable Workflow**: Call from any authorized repository using `workflow_call`
- **Hardcoded Generator Settings**: Consistent client generation with standardized configuration
- **Authorization Control**: Only authorized repositories can trigger the workflow
- **Dry-Run Mode**: Test client generation without publishing

## Usage

### Calling the Reusable Workflow

Add the following workflow to your repository (e.g., `.github/workflows/update-api-client.yml`):

```yaml
name: Update API Client Package

on:
  push:
    branches: [main]
    paths: ['api/openapi.yaml']
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to publish'
        required: true

# Required for npm Trusted Publishing (OIDC)
permissions:
  id-token: write
  contents: read

jobs:
  generate-client:
    uses: kubev2v/migration-planner-client-generator/.github/workflows/generate-and-publish.yml@main
    with:
      openapi-spec-url: "https://raw.githubusercontent.com/your-org/your-repo/main/api/openapi.yaml"
      package-name: "@your-scope/api-client"
      package-version: ${{ inputs.version || '0.0.1' }}
    # Required: passes OIDC permissions to the reusable workflow
    secrets: inherit
```

### Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `openapi-spec-url` | Yes | - | URL to the OpenAPI specification file |
| `package-name` | Yes | - | npm package name (e.g., `@scope/package-name`) |
| `package-version` | Yes | - | Package version to publish (semver) |
| `npm-registry` | No | `https://registry.npmjs.org` | npm registry URL |
| `dry-run` | No | `false` | Skip npm publish (for testing) |

### npm Publishing Authentication

This workflow uses **npm Trusted Publishing (OIDC)** as the primary authentication method:

- **No long-lived npm tokens needed** - OIDC provides short-lived, workflow-specific credentials
- Requires `id-token: write` permission in calling workflow
- Requires [Trusted Publisher](https://docs.npmjs.com/trusted-publishers) configured on npmjs.com
- Use `secrets: inherit` to pass OIDC permissions to the reusable workflow

### Required Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `NPM_TOKEN` | No | Only needed for local testing with act-cli (OIDC fallback) |

Authorization is controlled by `.github/allowed_repos.json` in this repository (see [Authorization Model](#authorization-model)).

## Generator Configuration

The workflow uses hardcoded generator settings that **cannot be modified by callers**:

| Setting | Value |
|---------|-------|
| Generator | `typescript-fetch` |
| Output Directory | `generated-client` |
| `ensureUniqueParams` | `true` |
| `supportsES6` | `true` |
| `withInterfaces` | `true` |
| `importFileExtension` | `.js` |

These settings match the configuration in [kubev2v/migration-planner-ui](https://github.com/kubev2v/migration-planner-ui).

## Authorization Model

### How Authorization Works

The workflow includes a mandatory authorization check before generating and publishing clients.

1. **Self-Authorization**: Calls from this repository (`kubev2v/migration-planner-client-generator`) are automatically authorized for CI/testing purposes
2. **File-based Allowlist**: External repositories must be listed in `.github/allowed_repos.json` in this repository (source of truth)
3. **Exact Match**: Uses `jq` for precise string matching (no partial matches)
4. **Fail-Fast**: Unauthorized requests are rejected before any generation occurs

The workflow fetches the allowlist from the `main` branch at run time, so updates take effect as soon as they are merged.

### Adding an Authorized Repository

Edit `.github/allowed_repos.json` in this repository and add the repo to the JSON array:

```json
["kubev2v/migration-planner", "kubev2v/assisted-migration-agent"]
```

> **Note**: You don't need to add this repository to the file—it's automatically authorized.

### Security Features

- Single source of truth in the repo; only maintainers can change the list
- Exact string matching prevents partial name attacks
- JSON format is validated before use

## Local Development

### Testing with act-cli

Use [act](https://github.com/nektos/act) to test GitHub Actions locally:

```bash
# Install act (macOS)
brew install act

# Setup secrets file (first time)
make setup-secrets

# Run test workflow (dry-run mode - no npm publishing)
make test

# Run test workflow with actual npm publishing (requires real NPM_TOKEN)
make test-publish

# Cleanup generated files
make clean
```

### Allowlist tests (no Docker)

Run allowlist validation and authorize logic tests without act/Docker:

```bash
make test-allowlist
```

These tests validate `.github/allowed_repos.json` (valid JSON, array of strings) and that the same allow/deny logic as the workflow behaves correctly (same-repo allowed, list lookup, exact match).

### Make Targets

| Command | Description |
|---------|-------------|
| `make test` | Run workflow in dry-run mode via act (tests generation/build only) |
| `make test-allowlist` | Run allowlist and authorize logic tests (no Docker) |
| `make test-all` | Run test-allowlist then make test |
| `make test-publish` | Run workflow with actual npm publishing + cleanup |
| `make test-verbose` | Run workflow with verbose output |
| `make setup-secrets` | Create `.secrets` file template |
| `make clean` | Remove generated artifacts |

### CI Feature Toggle

The test workflow runs in **dry-run mode by default** to avoid npm rate limits.

To enable actual npm publishing in CI:
1. Go to Settings > Secrets and variables > Actions > Variables
2. Add: `TEST_NPM_PUBLISH` = `true`
3. Bump `TEST_PACKAGE_VERSION` in `test.yml` before each test

When enabled, test packages are automatically unpublished after successful publish.

## Repository Structure

```
.
├── .github/
│   ├── allowed_repos.json             # Allowed callers (source of truth)
│   └── workflows/
│       ├── generate-and-publish.yml   # Reusable workflow
│       └── test.yml                   # CI test workflow
├── tests/
│   ├── validate_allowed_repos.sh      # Validate allowlist JSON
│   └── test_authorize_logic.sh       # Test authorize allow/deny logic
├── .actrc                             # act-cli configuration
├── .gitignore                         # Ignores generated-client/, secrets, etc.
├── Makefile                           # Local testing commands (make test, make test-allowlist, etc.)
├── AGENTS.md                          # AI agent guidelines
├── LICENSE                            # Apache-2.0
└── README.md                          # This file
```

## Related

- [ECOPROJECT-3956](https://issues.redhat.com/browse/ECOPROJECT-3956) - Jira issue for this project
- [kubev2v/migration-planner-ui](https://github.com/kubev2v/migration-planner-ui) - UI monorepo using this workflow
- [kubev2v/migration-planner](https://github.com/kubev2v/migration-planner) - Backend API repository
- [openapi-generator](https://openapi-generator.tech/) - OpenAPI Generator documentation

## License

Apache-2.0
