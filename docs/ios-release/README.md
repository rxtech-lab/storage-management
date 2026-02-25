# Automated iOS Release Workflow

This document describes how the repository handles automated iOS releases using a two-stage pipeline: **GitHub Actions** for CI and semantic versioning, and **Xcode Cloud** for App Store distribution.

## Table of Contents

- [Overview](#overview)
- [Release Flow](#release-flow)
- [Stage 1: GitHub Actions CI](#stage-1-github-actions-ci)
  - [Continuous Integration (ios-ci.yml)](#continuous-integration)
  - [Reusable Setup Workflow (ios-setup.yml)](#reusable-setup-workflow)
  - [Creating a Release (create-release.yaml)](#creating-a-release)
  - [Semantic Release Configuration](#semantic-release-configuration)
- [Stage 2: Xcode Cloud](#stage-2-xcode-cloud)
  - [Post-Clone Script (ci_post_clone.sh)](#post-clone-script)
  - [Version Bumping from Tags](#version-bumping-from-tags)
  - [Environment Setup](#environment-setup)
- [Version Bumping Explained](#version-bumping-explained)
  - [How Versions Work in iOS](#how-versions-work-in-ios)
  - [Semantic Release Commit Conventions](#semantic-release-commit-conventions)
  - [End-to-End Version Flow](#end-to-end-version-flow)
- [Secrets Management](#secrets-management)
- [File Reference](#file-reference)

## Overview

The release pipeline uses two CI systems with distinct responsibilities:

| System | Responsibility |
|--------|---------------|
| **GitHub Actions** | Build verification, testing, semantic versioning, GitHub Release creation |
| **Xcode Cloud** | App Store builds, code signing, version stamping from git tags, TestFlight/App Store distribution |

```
Push to main
     │
     ▼
GitHub Actions ──► Build + Test (iOS, macOS, App Clips, UI Tests)
     │
     ▼
Manual Trigger ──► Semantic Release ──► Analyzes commits
                        │                  │
                        │           ┌──────┴──────┐
                        │           │  No release  │ (no feat/fix commits)
                        │           │  commits     │
                        │           └──────────────┘
                        │
                        ▼
                  Creates git tag (v1.2.3)
                  Creates GitHub Release with notes
                        │
                        ▼
              Xcode Cloud detects tag ──► ci_post_clone.sh
                        │                     │
                        │              Extracts version from CI_TAG
                        │              Updates MARKETING_VERSION
                        │              Updates CURRENT_PROJECT_VERSION
                        │                     │
                        ▼                     ▼
                  Xcode Cloud builds ──► App Store / TestFlight
```

## Release Flow

1. Developers push commits to `main` using [Conventional Commits](https://www.conventionalcommits.org/)
2. GitHub Actions runs CI on every push (build, test, lint)
3. A maintainer manually triggers the **Create Release** workflow
4. Semantic Release analyzes commit messages since the last tag and determines the version bump
5. A new git tag (e.g., `v1.2.3`) and GitHub Release are created
6. Xcode Cloud detects the tag and starts a build
7. The `ci_post_clone.sh` script extracts the version from the tag and stamps it into the Xcode project
8. Xcode Cloud builds, signs, and distributes to TestFlight / App Store

## Stage 1: GitHub Actions CI

### Continuous Integration

**File:** `.github/workflows/ios-ci.yml`

Runs on every push to any branch. Executes five parallel jobs via the reusable `ios-setup.yml` workflow:

| Job | Script | Runner | Purpose |
|-----|--------|--------|---------|
| Build iOS App | `ios-build.sh` | `macos-latest` | Verify iOS simulator build |
| Build macOS App | `macos-build.sh` | `macos-26` | Verify macOS build |
| Run Tests | `ios-test.sh` | `macos-26` | Swift Package unit tests |
| Build App Clips | `ios-build.sh` | `macos-latest` | Verify App Clips target |
| Run UI Tests | `ios-ui-test.sh` | `self-hosted` | End-to-end UI tests |

Uses concurrency groups to cancel in-progress builds when new commits are pushed to the same branch:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Reusable Setup Workflow

**File:** `.github/workflows/ios-setup.yml`

A `workflow_call` reusable workflow that all CI jobs share. It handles:

1. **Checkout** code
2. **Setup tooling** - Bun (latest), Xcode (latest-stable), xcbeautify
3. **Decode secrets** - Writes `Secrets.xcconfig`, `RxStorage/.env`, and `admin/.env` from base64-encoded GitHub Secrets
4. **Cache** Xcode derived data keyed on `Package.swift` hash
5. **Start backend** - Installs admin dependencies and runs `bun dev:e2e` in background
6. **Generate OpenAPI client** - Runs `./scripts/ios-update-openapi.sh` to regenerate the iOS API client from the live backend
7. **Execute script** - Runs the job-specific script (`ios-build.sh`, `ios-test.sh`, etc.)
8. **Upload artifacts** - Build logs, backend logs, test results (`.xcresult`), and screenshots on failure

### Creating a Release

**File:** `.github/workflows/create-release.yaml`

```yaml
on: workflow_dispatch
name: Create a new release

jobs:
  create-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    if: ${{ (github.event.pusher.name != 'github action') && (github.ref == 'refs/heads/main') }}
    steps:
      - name: Checkout
        uses: actions/checkout@v6
      - name: Semantic Release
        uses: cycjimmy/semantic-release-action@v6
        env:
          GITHUB_TOKEN: ${{ secrets.RELEASE_TOKEN }}
        with:
          branch: main
```

Key details:
- **Manually triggered** (`workflow_dispatch`) - not automatic on push
- **Only runs on `main`** - the `if` condition enforces this
- **Guard against loops** - skips if the pusher is `github action`
- **Uses `RELEASE_TOKEN`** - a GitHub PAT with `contents: write` permission

### Semantic Release Configuration

**File:** `.releaserc`

```json
{
    plugins: [
        '@semantic-release/commit-analyzer',
        '@semantic-release/release-notes-generator',
        '@semantic-release/github'
    ]
}
```

Three plugins handle the full release lifecycle:

| Plugin | Purpose |
|--------|---------|
| `commit-analyzer` | Parses conventional commits to determine version bump type |
| `release-notes-generator` | Auto-generates changelog from commit messages |
| `github` | Creates the GitHub Release with the tag and release notes |

## Stage 2: Xcode Cloud

### Post-Clone Script

**File:** `RxStorage/ci_scripts/ci_post_clone.sh`

Xcode Cloud runs scripts in `ci_scripts/` at specific lifecycle points. The `ci_post_clone.sh` script executes immediately after Xcode Cloud clones the repository.

It performs these steps in order:

1. **Trust Swift Package plugins** - Required for the OpenAPI code generator
2. **Bump version from tag** - If `CI_TAG` is set, extract version and stamp it into the Xcode project
3. **Decode secrets** - Write `Secrets.xcconfig` from `SECRETS_XCCONFIG_BASE64` environment variable
4. **Decode test credentials** - Run `scripts/decode-env-secrets.sh`
5. **Install Bun** - Download and configure Bun runtime
6. **Start backend server** - Install dependencies and run `bun dev:e2e` in background
7. **Wait for backend** - Poll `http://localhost:3000` up to 60 seconds
8. **Generate OpenAPI client** - Run `scripts/ios-update-openapi.sh`

### Version Bumping from Tags

The core version bumping logic in `ci_post_clone.sh`:

```bash
if [ -n "$CI_TAG" ]; then
    VERSION="${CI_TAG#v}"   # v1.2.3 → 1.2.3
    echo "Setting MARKETING_VERSION=$VERSION, CURRENT_PROJECT_VERSION=$CI_BUILD_NUMBER"
    cd "$REPO_ROOT/RxStorage"

    # Update MARKETING_VERSION in the Xcode project file directly
    # (agvtool new-marketing-version only updates Info.plist, not the
    # build setting used when GENERATE_INFOPLIST_FILE=YES)
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" \
        RxStorage.xcodeproj/project.pbxproj

    # Update CURRENT_PROJECT_VERSION (build number) using agvtool
    agvtool new-version -all "$CI_BUILD_NUMBER"
    cd "$REPO_ROOT"
fi
```

How it works:

1. **`CI_TAG`** - Xcode Cloud sets this environment variable when the build is triggered by a git tag
2. **Strip `v` prefix** - `${CI_TAG#v}` converts `v1.2.3` to `1.2.3`
3. **`MARKETING_VERSION`** - The user-facing version string (e.g., "1.2.3") shown in the App Store. Updated via `sed` directly in `project.pbxproj` because `agvtool new-marketing-version` only updates `Info.plist`, but with `GENERATE_INFOPLIST_FILE=YES`, Xcode reads the build setting instead
4. **`CURRENT_PROJECT_VERSION`** - The build number (e.g., 42), set to Xcode Cloud's auto-incrementing `CI_BUILD_NUMBER` via `agvtool new-version -all`

### Environment Setup

Xcode Cloud environment variables (configured in Xcode Cloud settings):

| Variable | Purpose |
|----------|---------|
| `CI_TAG` | Auto-set by Xcode Cloud when triggered by a git tag |
| `CI_BUILD_NUMBER` | Auto-incrementing build number from Xcode Cloud |
| `SECRETS_XCCONFIG_BASE64` | Base64-encoded `Secrets.xcconfig` with OAuth client IDs |
| `RXSTORAGE_TESTING_SECRETS` | Base64-encoded `.env` with test credentials |

## Version Bumping Explained

### How Versions Work in iOS

iOS apps have two version identifiers:

| Field | Xcode Build Setting | Example | Purpose |
|-------|---------------------|---------|---------|
| Version | `MARKETING_VERSION` | `1.2.3` | User-facing version in the App Store |
| Build | `CURRENT_PROJECT_VERSION` | `42` | Internal build number, must increment per submission |

The repository keeps default values in the Xcode project file:

```
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 5
```

These are **overwritten at build time** by the `ci_post_clone.sh` script when Xcode Cloud builds from a tag. The version in the project file is not bumped in the repository itself - it's only stamped during the CI build.

### Semantic Release Commit Conventions

Version bumps are determined by commit message prefixes:

| Commit Prefix | Version Bump | Example |
|--------------|-------------|---------|
| `fix:` | Patch (1.0.0 → 1.0.1) | `fix: resolve crash on item delete` |
| `feat:` | Minor (1.0.0 → 1.1.0) | `feat: add QR code scanning` |
| `BREAKING CHANGE:` | Major (1.0.0 → 2.0.0) | `feat!: redesign API response format` |
| `chore:`, `docs:`, `ci:` | No release | `chore: update dependencies` |

### End-to-End Version Flow

Example: releasing version `v1.2.0`

```
1. Developer commits:
   feat: add stock history support
   fix: photo picker error

2. Maintainer triggers "Create Release" workflow on main

3. Semantic Release:
   - Finds feat: commit → minor bump
   - Last tag was v1.1.1 → new version is v1.2.0
   - Creates git tag: v1.2.0
   - Creates GitHub Release with auto-generated notes

4. Xcode Cloud detects tag v1.2.0:
   - CI_TAG = "v1.2.0"
   - CI_BUILD_NUMBER = 47 (auto-incremented)

5. ci_post_clone.sh runs:
   - VERSION = "1.2.0" (stripped "v" prefix)
   - sed updates MARKETING_VERSION = 1.2.0 in project.pbxproj
   - agvtool sets CURRENT_PROJECT_VERSION = 47

6. Xcode Cloud builds, signs, uploads to TestFlight
   - App Store shows: Version 1.2.0 (47)
```

Current tags in the repository:

| Tag | Version |
|-----|---------|
| `v1.1.1` | 1.1.1 |
| `v1.1.0` | 1.1.0 |
| `v1.0.0` | 1.0.0 |

## Secrets Management

Both CI systems use the same secrets, encoded in base64:

| Secret | GitHub Actions | Xcode Cloud | Contents |
|--------|---------------|-------------|----------|
| `SECRETS_XCCONFIG_BASE64` | GitHub Secret | Environment Variable | OAuth client IDs (`AUTH_CLIENT_ID_DEV`, `AUTH_CLIENT_ID_PROD`) |
| `RXSTORAGE_TESTING_SECRETS` | GitHub Secret | Environment Variable | Test credentials for E2E tests |
| `ADMIN_ENV_BASE64` | GitHub Secret | N/A | Backend `.env` (database URL, auth config) |
| `RELEASE_TOKEN` | GitHub Secret | N/A | GitHub PAT for creating releases |

Secrets are decoded identically in both systems:

```bash
echo "$SECRETS_XCCONFIG_BASE64" | base64 --decode > Secrets.xcconfig
```

## File Reference

| File | Purpose |
|------|---------|
| `.github/workflows/ios-ci.yml` | Main CI workflow - triggers builds and tests on every push |
| `.github/workflows/ios-setup.yml` | Reusable workflow with shared CI setup (secrets, tooling, backend) |
| `.github/workflows/create-release.yaml` | Manual workflow to create a semantic release |
| `.releaserc` | Semantic release plugin configuration |
| `RxStorage/ci_scripts/ci_post_clone.sh` | Xcode Cloud post-clone script - version bumping and environment setup |
| `scripts/ios-build.sh` | iOS simulator build script |
| `scripts/ios-test.sh` | Swift Package unit test runner |
| `scripts/ios-ui-test.sh` | UI test runner with backend server |
| `scripts/macos-build.sh` | macOS build script |
| `scripts/ios-update-openapi.sh` | OpenAPI client regeneration |
| `scripts/decode-env-secrets.sh` | Decodes base64 test secrets to `.env` |
