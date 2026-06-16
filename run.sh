#!/bin/bash

# run.sh - Custom initialization and lifecycle management for branch environment
# This script runs inside the Drupal container and stays running
# It starts with docker-compose up and stops with docker-compose down

set -e

BRANCH_NAME="${BRANCH_NAME:-source}"

echo "🚀 Starting branch lifecycle manager for: $BRANCH_NAME"

# Function to handle cleanup on exit
cleanup() {
    echo "🛑 Stopping lifecycle manager for $BRANCH_NAME..."
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap cleanup SIGTERM SIGINT

# Log file
LOG_DIR="/tmp"
LOG_FILE="$LOG_DIR/branch-${BRANCH_NAME}-run.log"

echo "[$(date)] ✅ Branch $BRANCH_NAME environment is running" >> "$LOG_FILE"

# ============================================
# CUSTOM INITIALIZATION LOGIC HERE
# ============================================

# Example 1: Wait for Drupal to be fully initialized
echo "⏳ Waiting for Drupal to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f -s http://localhost/admin &>/dev/null; then
        echo "✅ Drupal is ready at http://$BRANCH_NAME.docker"
        echo "[$(date)] ✅ Drupal ready" >> "$LOG_FILE"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 1
done

# Example 2: Run custom scripts or hooks
echo "🔧 Running custom initialization scripts..."

# Create a marker file to indicate this branch is running
touch /tmp/.${BRANCH_NAME}-running

# ============================================
# KEEP PROCESS ALIVE
# ============================================

echo "✅ All initialization complete. Keeping environment alive..."
echo "[$(date)] ✅ Initialization complete, keeping process alive" >> "$LOG_FILE"

# Keep the script running indefinitely
# This allows docker-compose to manage the lifecycle
while true; do
    sleep 3600  # Check every hour (or use longer intervals)
    echo "[$(date)] 🟢 Health check: $BRANCH_NAME is still running" >> "$LOG_FILE"
done
