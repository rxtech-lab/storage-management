# Local Development with dev:e2e

This guide explains how to run the admin app in local development mode with file-based SQLite and local S3.

## Overview

The `dev:e2e` script provides a complete local development environment:
- **File-based SQLite database** (instead of Turso)
- **Local S3 server** using s3rver (instead of remote S3)
- **Auto-migration** on first run
- **No Docker required** (works on macOS GitHub Actions)

## Quick Start

```bash
# 1. Copy environment template
cp .env.local.example .env.local

# 2. Edit .env.local with your auth credentials
# (AUTH_SECRET, AUTH_CLIENT_ID, AUTH_CLIENT_SECRET)

# 3. Start dev:e2e environment
bun run dev:e2e
```

This will:
1. Create `.local-data/` directory for SQLite database
2. Run database migrations (if database doesn't exist)
3. Start local S3 server on port 4569
4. Start Next.js dev server on port 3000

## Environment Variables

When running `dev:e2e`, these variables are automatically set:

```bash
# Database
USE_LOCAL_DB=true
LOCAL_DB_PATH=.local-data/local.db

# S3
LOCAL_S3_PORT=4569
AWS_ENDPOINT_URL=http://localhost:4569
AWS_ACCESS_KEY_ID=S3RVER
AWS_SECRET_ACCESS_KEY=S3RVER
AWS_REGION=us-east-1
```

## S3 Endpoint

**When using `dev:e2e`, the S3 endpoint is: `http://localhost:4569`**

The local S3 server (s3rver):
- Runs on port 4569 by default
- Stores data in `.local-s3/` directory
- Compatible with AWS S3 API
- Uses dummy credentials (S3RVER/S3RVER)

## Database Management

### View/Edit Database

```bash
# Open Drizzle Studio for local database
bun run db:studio:local
```

### Push Schema Changes

```bash
# Push schema changes to local database
bun run db:push:local
```

### Reset Database

```bash
# Delete database and restart
rm -rf .local-data/
bun run dev:e2e  # Will recreate and migrate
```

## File Structure

```
.local-data/           # Local SQLite database (gitignored)
  └── local.db
.local-s3/             # Local S3 data (gitignored)
  └── [buckets]/
scripts/
  ├── dev-e2e.sh      # Main startup script
  └── start-local-s3.sh  # S3 server script
drizzle.config.local.ts  # Drizzle config for local DB
```

## Comparison: dev vs dev:e2e

| Feature | `bun run dev` | `bun run dev:e2e` |
|---------|---------------|-------------------|
| Database | Remote Turso | Local SQLite file |
| S3 | Remote S3/R2 | Local s3rver (port 4569) |
| Auth | OAuth (prod) | OAuth (prod) |
| Migrations | Manual | Auto on first run |
| Data persistence | Cloud | Local `.local-data/` |

## Troubleshooting

### Port 4569 already in use

```bash
# Find and kill the process using port 4569
lsof -ti:4569 | xargs kill -9
```

### Database locked error

```bash
# Stop all processes and remove lock files
rm .local-data/*.db-shm .local-data/*.db-wal
```

### S3 upload fails

Check that `AWS_ENDPOINT_URL` is set:
```bash
echo $AWS_ENDPOINT_URL  # Should output: http://localhost:4569
```

## CI/CD Usage

The `dev:e2e` setup is designed for local development and can also be used in CI environments that don't support Docker (like macOS GitHub Actions):

```yaml
# .github/workflows/test.yml
- name: Start local services
  run: bun run dev:e2e &

- name: Wait for services
  run: sleep 5

- name: Run tests
  run: bun run test:e2e
```

## Cleaning Up

Local data is stored in gitignored directories:
- `.local-data/` - SQLite database
- `.local-s3/` - S3 object storage

To clean up:
```bash
rm -rf .local-data/ .local-s3/
```
