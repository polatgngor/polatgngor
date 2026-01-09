#!/bin/bash
echo "🚀 Taksibu Backend Deployment Starting..."

# Detect Docker Compose command in a generic way (dash/bash compatible)
# We prioritize 'docker compose' (v2) as it's the modern standard.

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Error: Docker Compose not found. Please install Docker first."
    exit 1
fi

echo "ℹ️ Using command: $COMPOSE_CMD"

# 1. Stop existing containers
echo "🛑 Stopping containers..."
$COMPOSE_CMD down

# 1.5. Prepare Directories & Permissions (Fixes EACCES on VPS)
echo "📂 Setting up upload directories..."
mkdir -p uploads
chmod 777 uploads
# Also ensure subdirectories exist to avoid race conditions
mkdir -p uploads/drivers
chmod 777 uploads/drivers

# 2. Build and Start
echo "🏗️ Building and Starting..."
$COMPOSE_CMD up -d --build

# 3. Cleanup unused images
echo "🧹 Cleaning up..."
docker image prune -f

echo "✅ Deployment Complete! Server running on Port 3000."
$COMPOSE_CMD ps
