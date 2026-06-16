#!/bin/bash

# Database copy script: copies source database to branch environment
# Runs once on first branch creation

set -e

BRANCH_NAME="${1:-source}"
SOURCE_DIR="${2:-.}"
TARGET_DIR="${3:-.}"

echo "📊 Initializing database for branch: $BRANCH_NAME"

# Check if database has already been initialized (marker file)
if [ -f "$TARGET_DIR/.db-initialized" ]; then
    echo "✅ Database already initialized for $BRANCH_NAME. Skipping copy."
    exit 0
fi

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL container to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker exec "${BRANCH_NAME}_db" mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
        echo "✅ MySQL is ready"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS... waiting"
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ MySQL failed to start after $MAX_ATTEMPTS attempts"
    exit 1
fi

# Export database from source
echo "📥 Exporting database from source..."
docker exec "${BRANCH_NAME%_*}_source_db" mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" > /tmp/db_dump_${BRANCH_NAME}.sql 2>/dev/null || {
    echo "⚠️  Could not dump from source, creating fresh database"
    docker exec "${BRANCH_NAME}_db" mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};"
    touch "$TARGET_DIR/.db-initialized"
    exit 0
}

# Import database to target branch
echo "📤 Importing database to branch $BRANCH_NAME..."
docker exec -i "${BRANCH_NAME}_db" mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" < /tmp/db_dump_${BRANCH_NAME}.sql

# Cleanup
rm -f /tmp/db_dump_${BRANCH_NAME}.sql

# Mark as initialized
touch "$TARGET_DIR/.db-initialized"

echo "✅ Database initialization complete for $BRANCH_NAME"
