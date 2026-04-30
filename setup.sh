#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Homelab DNS Setup Automation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
        exit 1
    fi

    if ! command -v htpasswd &> /dev/null; then
        echo -e "${YELLOW}htpasswd not found. Installing apache2-utils...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y apache2-utils
        elif command -v yum &> /dev/null; then
            sudo yum install -y httpd-tools
        else
            echo -e "${RED}Cannot install apache2-utils automatically. Please install it manually.${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

setup_env() {
    echo -e "${YELLOW}Setting up environment variables...${NC}"

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            echo -e "${GREEN}Created .env from .env.example${NC}"
        else
            echo -e "${RED}.env.example not found!${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}.env already exists${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Please enter your Cloudflare API Token (or press Enter to skip):${NC}"
    read -r cf_token

    if [ -n "$cf_token" ]; then
        sed -i "s|CF_DNS_API_TOKEN=.*|CF_DNS_API_TOKEN=$cf_token|" .env
        echo -e "${GREEN}Cloudflare API Token updated in .env${NC}"
    fi
}

create_directories() {
    echo -e "${YELLOW}Creating required directories...${NC}"

    dirs=(
        "traefik/acme"
        "crowdsec/data"
        "adguard/work"
        "adguard/conf"
        "adguard/work/log"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "${GREEN}Created: $dir${NC}"
        else
            echo -e "${GREEN}Already exists: $dir${NC}"
        fi
    done
}

setup_acme() {
    echo -e "${YELLOW}Setting up ACME certificate storage...${NC}"

    if [ ! -f traefik/acme/acme.json ]; then
        echo "{}" > traefik/acme/acme.json
        chmod 600 traefik/acme/acme.json
        echo -e "${GREEN}Created acme.json with proper permissions${NC}"
    else
        echo -e "${GREEN}acme.json already exists${NC}"
    fi
}

setup_dashboard_auth() {
    echo -e "${YELLOW}Setting up Traefik Dashboard authentication...${NC}"

    echo -e "${YELLOW}Enter username for Traefik dashboard (default: admin):${NC}"
    read -r username
    username=${username:-admin}

    echo -e "${YELLOW}Enter password for Traefik dashboard:${NC}"
    read -rs password

    if [ -z "$password" ]; then
        echo -e "${RED}Password cannot be empty${NC}"
        exit 1
    fi

    hash=$(htpasswd -nbB "$username" "$password" | tr -d '\n')

    if grep -q "dashboard-auth" traefik/dynamic/middlewares.yml; then
        sed -i "/dashboard-auth:/,/users:/c\\
    dashboard-auth:\\
      basicAuth:\\
        users:\\
          - \"$hash\"" traefik/dynamic/middlewares.yml
        echo -e "${GREEN}Updated dashboard authentication in middlewares.yml${NC}"
    fi
}

setup_ip_whitelist() {
    echo -e "${YELLOW}Setting up IP whitelist...${NC}"

    echo -e "${YELLOW}Enter your local network CIDR (default: 192.168.1.0/24):${NC}"
    read -r network
    network=${network:-192.168.1.0/24}

    if grep -q "dashboard-ipwhitelist" traefik/dynamic/middlewares.yml; then
        sed -i "/dashboard-ipwhitelist:/,/sourceRange:/c\\
    dashboard-ipwhitelist:\\
      ipAllowList:\\
        sourceRange:\\
          - \"$network\"" traefik/dynamic/middlewares.yml
        echo -e "${GREEN}Updated IP whitelist to $network${NC}"
    fi
}

setup_domain() {
    echo -e "${YELLOW}Setting up domain for Traefik dashboard...${NC}"

    echo -e "${YELLOW}Enter your domain (e.g., example.com):${NC}"
    read -r domain

    if [ -z "$domain" ]; then
        echo -e "${RED}Domain cannot be empty${NC}"
        exit 1
    fi

    if grep -q "traefik.seudominio.com" traefik/dynamic/dashboard.yml; then
        sed -i "s|traefik.seudominio.com|traefik.$domain|g" traefik/dynamic/dashboard.yml
        echo -e "${GREEN}Updated domain to traefik.$domain${NC}"
    fi

    if grep -q "certResolver: cloudflare" traefik/traefik.yml; then
        echo -e "${YELLOW}Don't forget to update your email in traefik/traefik.yml for Let's Encrypt${NC}"
    fi
}

generate_crowdsec_api_key() {
    echo -e "${YELLOW}Generating CrowdSec Bouncer API Key...${NC}"

    echo -e "${YELLOW}Starting CrowdSec to generate API key...${NC}"
    docker compose up -d crowdsec
    sleep 10

    echo -e "${YELLOW}Generating bouncer API key...${NC}"
    api_key=$(docker exec crowdsec cscli bouncers add traefik-bouncer -o raw)

    if [ -n "$api_key" ]; then
        sed -i "s|CROWDSEC_BOUNCER_API_KEY: CHANGE_ME|CROWDSEC_BOUNCER_API_KEY: $api_key|" docker-compose.yml
        echo -e "${GREEN}CrowdSec Bouncer API Key generated and saved${NC}"
        echo -e "${YELLOW}API Key: $api_key${NC}"
    else
        echo -e "${RED}Failed to generate API key${NC}"
    fi
}

update_adguard_config() {
    echo -e "${YELLOW}Updating AdGuardHome configuration...${NC}"

    if [ -f adguard/conf/AdGuardHome.yaml ]; then
        echo -e "${YELLOW}Enter password for AdGuard (will be hashed):${NC}"
        read -rs ag_password

        if [ -n "$ag_password" ]; then
            hash=$(docker run --rm httpd:2.4 htpasswd -nbB admin "$ag_password" 2>/dev/null | cut -d: -f2)
            if [ -n "$hash" ]; then
                sed -i "s|password: \\$2y\\$12\\$CHANGE_ME_HASH|password: $hash|" adguard/conf/AdGuardHome.yaml
                echo -e "${GREEN}AdGuard password updated${NC}"
            fi
        fi
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review traefik/traefik.yml and update email for Let's Encrypt"
    echo "2. Run: docker compose up -d"
    echo "3. Access Traefik Dashboard: https://traefik.yourdomain.com"
    echo "4. Access AdGuard Home: http://your-server-ip:3000"
    echo "5. Configure your router to use your server's IP as DNS"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  make up          - Start all services"
    echo "  make logs        - View logs"
    echo "  make status      - Check status"
    echo "  make down        - Stop all services"
    echo ""
}

main() {
    check_dependencies
    setup_env
    create_directories
    setup_acme
    setup_dashboard_auth
    setup_ip_whitelist
    setup_domain
    update_adguard_config

    echo ""
    echo -e "${YELLOW}Do you want to generate CrowdSec API key now? (y/n)${NC}"
    read -r generate_cs
    if [[ "$generate_cs" =~ ^[Yy]$ ]]; then
        generate_crowdsec_api_key
    fi

    print_summary
}

main
