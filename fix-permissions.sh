#!/bin/bash

# Fix permissions script for homelab
# Run this if you encounter permission errors with AdGuard or Traefik

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Fixing Permissions${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Stop containers first
echo -e "${YELLOW}Stopping containers...${NC}"
docker compose down

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

echo -e "${GREEN}Current user: $CURRENT_USER (UID: $CURRENT_UID, GID: $CURRENT_GID)${NC}"

# Fix AdGuard permissions
echo -e "${YELLOW}Fixing AdGuard permissions...${NC}"
if [ -d "adguard/work" ]; then
    sudo chown -R $CURRENT_UID:$CURRENT_GID adguard/work
    echo -e "${GREEN}✓ AdGuard work directory fixed${NC}"
fi

if [ -d "adguard/conf" ]; then
    sudo chown -R $CURRENT_UID:$CURRENT_GID adguard/conf
    echo -e "${GREEN}✓ AdGuard conf directory fixed${NC}"
fi

# Fix Traefik permissions
echo -e "${YELLOW}Fixing Traefik permissions...${NC}"
if [ -d "traefik/acme" ]; then
    sudo chown -R $CURRENT_UID:$CURRENT_GID traefik/acme
    if [ -f "traefik/acme/acme.json" ]; then
        chmod 600 traefik/acme/acme.json
    fi
    echo -e "${GREEN}✓ Traefik acme directory fixed${NC}"
fi

# CrowdSec runs as root, so we don't need to change its permissions
echo -e "${YELLOW}Skipping CrowdSec (runs as root)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Permissions Fixed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Now you can start the containers:${NC}"
echo "  make up"
