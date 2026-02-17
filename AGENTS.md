# AGENTS.md

Guidelines for AI agents working on this repository.

## Project Overview

This is a **GitOps repository** providing a reusable GitHub Actions workflow for generating and publishing OpenAPI clients to npm. It uses the `workflow_call` trigger pattern, allowing authorized external repositories to invoke it.

**Jira Issue:** [ECOPROJECT-3956](https://issues.redhat.com/browse/ECOPROJECT-3956)

## Architecture

```
.
├── .github/
│   ├── allowed_repos.json         # Source of truth: repos allowed to call the workflow
│   └── workflows/
│       ├── generate-and-publish.yml   # Main reusable workflow (workflow_call)
│       └── test.yml                   # CI test workflow
├── .actrc                         # act-cli configuration
├── .gitignore
├── LICENSE                        # Apache-2.0
├── Makefile                       # Local testing commands
└── README.md
```

### Key Components

1. **Reusable Workflow** (`.github/workflows/generate-and-publish.yml`)
   - Triggered via `workflow_call` from external repositories
   - Two jobs: `authorize` (security check) → `generate-and-publish`
   - Uses `openapi-generators/openapitools-generator-action@v1`
   - Output directory: `generated-client`

2. **Authorization Model**
   - **Self-authorization**: This repository is automatically authorized (for CI/testing)
   - External repos validated via `.github/allowed_repos.json` (source of truth in this repo)
   - Workflow fetches the file from `main`; file is a JSON array: `["org/repo1", "org/repo2"]`
   - Fails fast before any generation occurs

## Critical Constraints

### Hardcoded Generator Settings (DO NOT MODIFY)

These settings are intentionally hardcoded and must match [kubev2v/migration-planner-ui/openapitools.json](https://raw.githubusercontent.com/kubev2v/migration-planner-ui/refs/heads/main/openapitools.json):

| Setting | Value | Reason |
|---------|-------|--------|
| `generator` | `typescript-fetch` | Standardized across organization |
| `-o` (output) | `generated-client` | Consistent, generator-agnostic folder name |
| `ensureUniqueParams` | `true` | Required for API compatibility |
| `supportsES6` | `true` | Modern JavaScript support |
| `withInterfaces` | `true` | TypeScript interface generation |
| `importFileExtension` | `.js` | ESM module compatibility |

**Callers cannot override these settings.** This is by design to ensure consistent client generation.

### Workflow Inputs (Caller-Configurable)

| Input | Required | Description |
|-------|----------|-------------|
| `openapi-spec-url` | Yes | URL to OpenAPI spec file |
| `package-name` | Yes | npm package name (@scope/name) |
| `package-version` | Yes | Semver version to publish |
| `npm-registry` | No | Defaults to npmjs.org |
| `dry-run` | No | Skip publish (for testing) |

### npm Publishing Authentication

This workflow uses **npm Trusted Publishing (OIDC)** exclusively — no long-lived tokens:

- Requires `id-token: write` permission in calling workflow
- Requires Trusted Publisher configured on [npmjs.com](https://docs.npmjs.com/trusted-publishers)
- Calling workflow must use `secrets: inherit` to pass OIDC permissions
- Publishes with `--provenance` for supply-chain attestation

### Required Secrets

None. Authentication is handled entirely via OIDC Trusted Publishing.

**In calling repositories:**
- Calling workflow must have `permissions: id-token: write` for OIDC
- Use `secrets: inherit` to pass OIDC permissions to the reusable workflow

## Local Development

### Testing with act-cli

```bash
# Run tests (dry-run mode - no npm publishing)
make test

# Verbose output for debugging
make test-verbose

# Cleanup generated files
make clean
```

> **Note:** OIDC Trusted Publishing does not work locally with act-cli. Local testing is limited to dry-run mode. To test actual npm publishing, use the CI feature toggle described below.

### Prerequisites

- [act-cli](https://github.com/nektos/act): `brew install act`
- Docker must be running

### Test Modes

| Command | Mode | Description |
|---------|------|-------------|
| `make test` | Dry-run | Tests generation and build only (default, safe) |

### CI Feature Toggle

The test workflow runs in **dry-run mode by default** to avoid npm rate limits.

To enable actual npm publishing in CI (for debugging):
1. Go to Settings > Secrets and variables > Actions > Variables
2. Add repository variable: `TEST_NPM_PUBLISH` = `true`
3. Bump `TEST_PACKAGE_VERSION` in `test.yml` (npm doesn't allow reusing unpublished versions)

When publishing is enabled, the test package is automatically unpublished after success.

## Code Style Guidelines

### GitHub Actions Workflows

- Use descriptive step names with emoji prefixes (📥, 🔨, 🚀, ✅)
- Group related steps with comment headers using `# ---` separators
- Always validate inputs/secrets before using them
- Use `>-` for multi-line strings without trailing newlines
- Format `--additional-properties` as comma-separated key=value pairs (no spaces)

### Shell Scripts in Workflows

- Use `set -e` behavior (fail on errors)
- Validate environment variables exist before use
- Use `jq` for JSON processing (pre-installed on ubuntu-latest)
- Output to `$GITHUB_STEP_SUMMARY` for job summaries

## Security Considerations

1. **Use exact string matching** - `jq index()` prevents partial name attacks
2. **Validate JSON before parsing** - Use `jq empty` to verify format before use
3. **Allowed list is in repo** - `.github/allowed_repos.json` is the source of truth; only maintainers can change it
4. **Secrets are masked** - GitHub automatically masks secret values in logs

## Related Repositories

| Repository | Relationship |
|------------|--------------|
| [kubev2v/migration-planner](https://github.com/kubev2v/migration-planner) | Backend API, triggers client generation |
| [kubev2v/migration-planner-ui](https://github.com/kubev2v/migration-planner-ui) | Consumes generated `@migration-planner-ui/api-client` |

## Common Tasks

### Adding a New Authorized Repository

1. Edit `.github/allowed_repos.json` in this repository
2. Add the repo to the JSON array: `["existing/repo", "new/repo"]`
3. Commit and push to `main` (workflow fetches from `main`)

### Updating Generator Settings

**Warning:** Changes affect all consumers. Coordinate with dependent repositories.

1. Update `command-args` in `.github/workflows/generate-and-publish.yml`
2. Update the reference table in this file and README.md
3. Test with `make test` before committing
4. Notify teams using this workflow

### Debugging Authorization Failures

1. If calling from this repo: Should auto-authorize; check workflow syntax
2. If calling from external repo:
   - Ensure the repo is listed in `.github/allowed_repos.json` (exact `owner/repo` match, case-sensitive)
   - Check that the file is valid JSON and fetchable from `main` (raw GitHub URL)
