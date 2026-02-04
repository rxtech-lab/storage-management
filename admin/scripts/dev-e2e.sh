#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCAL_DATA_DIR="$PROJECT_ROOT/.local-data"
LOCAL_DB_PATH="$LOCAL_DATA_DIR/local.db"

echo "🚀 Starting dev:e2e environment..."
echo "================================================"

# Create local data directory if it doesn't exist
mkdir -p "$LOCAL_DATA_DIR"

# Export environment variables for local development
export USE_LOCAL_DB=true
export LOCAL_DB_PATH="$LOCAL_DB_PATH"
export LOCAL_S3_PORT=4569
export AWS_ENDPOINT_URL="http://localhost:4569"
export AWS_ACCESS_KEY_ID="S3RVER"
export AWS_SECRET_ACCESS_KEY="S3RVER"
export AWS_REGION="us-east-1"

# Remove existing database to start fresh
if [ -f "$LOCAL_DB_PATH" ]; then
  echo "🗑️  Removing existing database for fresh start..."
  rm -f "$LOCAL_DB_PATH"
fi

# Run migrations to initialize database
echo "📦 Running migrations..."
drizzle-kit push --config=drizzle.config.local.ts
echo "✅ Database initialized"

# Seed test data
echo "🌱 Seeding test data..."
bun run scripts/seed-e2e.ts
echo "✅ Database seeded"

echo "📦 Starting local S3 server on port $LOCAL_S3_PORT..."
echo "📦 Starting Next.js dev server..."
echo "================================================"

# Use concurrently to run both S3 server and Next.js dev server
# Kill all processes when one exits
concurrently \
  --kill-others \
  --names "S3,Next" \
  --prefix-colors "blue,green" \
  "bash $SCRIPT_DIR/start-local-s3.sh" \
  "next dev"
