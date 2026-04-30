.PHONY: up down restart logs status pull backup clean setup help

COMPOSE = docker compose

help:
	@echo "Homelab DNS Management"
	@echo ""
	@echo "Commands:"
	@echo "  make setup       - Run initial setup script"
	@echo "  make up          - Start all services"
	@echo "  make down        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make logs        - View logs (all services)"
	@echo "  make logs-svc    - View logs for specific service (make logs-svc svc=traefik)"
	@echo "  make status      - Check status of all services"
	@echo "  make pull        - Update all images"
	@echo "  make backup      - Backup volumes to ./backups/"
	@echo "  make clean       - Stop and remove all containers/volumes"
	@echo "  make health      - Check health of all services"
	@echo "  make test-health - Detailed health check with diagnostics"
	@echo "  make crowdsec    - Run cscli command (make crowdsec cmd='alerts list')"

setup:
	@bash setup.sh

up:
	$(COMPOSE) up -d
	@echo "Services started. Check status with: make status"

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f --tail=100

logs-svc:
	@if [ -z "$(svc)" ]; then \
		echo "Usage: make logs-svc svc=<service_name>"; \
		exit 1; \
	fi
	$(COMPOSE) logs -f --tail=100 $(svc)

status:
	$(COMPOSE) ps

pull:
	$(COMPOSE) pull
	$(COMPOSE) up -d

backup:
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	echo "Backing up volumes..."; \
	docker run --rm -v homelab_traefik-acme:/data -v $$(pwd)/backups:/backup alpine tar -czf /backup/traefik-acme_$$timestamp.tar.gz -C /data . 2>/dev/null || true; \
	tar -czf backups/adguard-work_$$timestamp.tar.gz adguard/work 2>/dev/null || true; \
	tar -czf backups/adguard-conf_$$timestamp.tar.gz adguard/conf 2>/dev/null || true; \
	tar -czf backups/crowdsec-data_$$timestamp.tar.gz crowdsec/data 2>/dev/null || true; \
	echo "Backup completed: ./backups/"

clean:
	$(COMPOSE) down -v
	@echo "All containers and volumes removed."

health:
	@echo "Checking service health..."
	@$(COMPOSE) ps -a | grep -E "(unhealthy|starting)" || echo "All services healthy"

test-health:
	@echo "=== Detailed Health Check ==="
	@echo ""
	@echo "Container Status:"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
	@echo ""
	@echo "Testing DNS Resolution:"
	@docker exec adguardhome nslookup google.com 172.18.0.10 2>&1 | head -5 || echo "AdGuard DNS test failed"
	@echo ""
	@echo "Testing Traefik:"
	@docker exec traefik wget --quiet --tries=1 --spider http://localhost:8080/ping && echo "Traefik: OK" || echo "Traefik: FAIL"
	@echo ""
	@echo "CrowdSec Bouncers:"
	@docker exec crowdsec cscli bouncers list 2>/dev/null || echo "CrowdSec not ready"

crowdsec:
	@if [ -z "$(cmd)" ]; then \
		echo "Usage: make crowdsec cmd='<cscli command>'"; \
		exit 1; \
	fi
	docker exec -it crowdsec cscli $(cmd)
