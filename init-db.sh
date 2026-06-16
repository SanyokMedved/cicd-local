#!/bin/bash

# Database copy script: copies source database to branch environment
# Runs once on first branch creation

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
    if docker exec "${BRANCH_NAME}_db" mysqladmin ping -u root -p${MYSQL_ROOT_PASSWORD} &>/dev/null; then
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

# Try to export and import database from source
echo "📥 Exporting database from source..."
DUMP_FILE="/tmp/db_dump_${BRANCH_NAME}.sql"

# Dump from source (redirect warnings to stderr only)
docker exec "source_db" mysqldump -u root -p${MYSQL_ROOT_PASSWORD} "${MYSQL_DATABASE}" > "$DUMP_FILE" 2>/dev/null

# Check if dump succeeded and has content
if [ -s "$DUMP_FILE" ] && grep -q "MySQL dump" "$DUMP_FILE"; then
    echo "📤 Importing database to branch $BRANCH_NAME..."
    if docker exec -i "${BRANCH_NAME}_db" mysql -u root -p${MYSQL_ROOT_PASSWORD} "${MYSQL_DATABASE}" < "$DUMP_FILE" 2>/dev/null; then
        echo "✅ Database initialized from source"
    else
        echo "⚠️  Import failed, creating empty database"
        docker exec "${BRANCH_NAME}_db" mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};" 2>/dev/null
    fi
else
    echo "⚠️  Could not export from source, creating empty database"
    docker exec "${BRANCH_NAME}_db" mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};" 2>/dev/null
fi

# Cleanup and mark as done
rm -f "$DUMP_FILE"
touch "$TARGET_DIR/.db-initialized"
echo "✅ Database initialization complete for $BRANCH_NAME"
