# CI/CD Workflows

This directory contains GitHub Actions workflows for the project.

## Workflows

### iOS CI (`ios-ci.yml`)

Builds and tests the iOS app on every push to `main` or `mobile-app` branches, and on pull requests to `main`.

**Features:**
- Builds the main RxStorage app
- Runs all unit tests with code coverage
- Builds the App Clips target
- Uploads build logs and test results as artifacts on failure

**Requirements:**
- macOS runner (uses `macos-latest`)
- Xcode 15.2+
- GitHub secret: `SECRETS_XCCONFIG_BASE64`

### E2E Tests (`e2e.yml`)

Runs end-to-end tests for the admin web application.

## GitHub Secrets Setup

### SECRETS_XCCONFIG_BASE64

The iOS app requires a `Secrets.xcconfig` file that contains OAuth client IDs and other sensitive configuration. This file is gitignored and must be provided via GitHub secrets.

#### Creating the Secret

1. **Encode your Secrets.xcconfig file:**

   ```bash
   # From the project root
   base64 -i RxStorage/RxStorage/Config/Secrets.xcconfig | pbcopy
   ```

   This copies the base64-encoded content to your clipboard.

2. **Add the secret to GitHub:**

   - Go to your repository on GitHub
   - Navigate to **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `SECRETS_XCCONFIG_BASE64`
   - Value: Paste the base64 string from step 1
   - Click **Add secret**

#### Secrets.xcconfig Format

Your `Secrets.xcconfig` file should look like this:

```xcconfig
// Secrets.xcconfig
// YOUR personal sensitive configuration values
// This file is gitignored and should NOT be committed

// Development OAuth Client ID
// Get this from your OAuth provider (auth.rxlab.app)
AUTH_CLIENT_ID_DEV = client_your_dev_id_here

// Production OAuth Client ID
// Get this from your OAuth provider (auth.rxlab.app)
AUTH_CLIENT_ID_PROD = client_your_prod_id_here

// Optional: Override API base URL for your local setup
// Uncomment if you need to point to a different local server
// API_BASE_URL = http://$()/192.168.1.100:3000
```

#### Updating the Secret

When you update your local `Secrets.xcconfig`:

1. Re-encode the file:
   ```bash
   base64 -i RxStorage/RxStorage/Config/Secrets.xcconfig | pbcopy
   ```

2. Update the secret on GitHub:
   - Go to **Settings** → **Secrets and variables** → **Actions**
   - Click on `SECRETS_XCCONFIG_BASE64`
   - Click **Update secret**
   - Paste the new base64 string
   - Click **Update secret**

#### What Happens in CI

The workflow decodes the secret and creates the `Secrets.xcconfig` file before building:

```yaml
- name: Setup Secrets.xcconfig from GitHub Secrets
  env:
    SECRETS_XCCONFIG_BASE64: ${{ secrets.SECRETS_XCCONFIG_BASE64 }}
  run: |
    echo "$SECRETS_XCCONFIG_BASE64" | base64 --decode > RxStorage/RxStorage/Config/Secrets.xcconfig
```

If the secret is not set, the workflow creates a placeholder file with dummy values so the build doesn't fail, but the app won't be functional.

## Local Development

For local development, create your own `Secrets.xcconfig` file:

```bash
# Copy the example file
cp RxStorage/RxStorage/Config/Secrets.xcconfig.example RxStorage/RxStorage/Config/Secrets.xcconfig

# Edit with your actual values
# DO NOT commit this file - it's gitignored
```

## Running Scripts Locally

You can run the build and test scripts locally:

```bash
# Build the iOS app
./scripts/ios-build.sh

# Run tests
./scripts/ios-test.sh

# Override configuration
SCHEME=RxStorageClips ./scripts/ios-build.sh
```

## Troubleshooting

### Build fails with "Secrets.xcconfig not found"

Make sure the `SECRETS_XCCONFIG_BASE64` GitHub secret is set correctly.

### Build fails with "No such file or directory"

Ensure you're running the scripts from the project root directory.

### Tests fail on specific simulator

Update the `DESTINATION` environment variable in the workflow or when running locally:

```bash
DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=17.0" ./scripts/ios-test.sh
```
