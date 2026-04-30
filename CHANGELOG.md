# Changelog - Homelab Stack

## [Unreleased] - 2026-04-30

### Fixed
- **Healthchecks corrigidos** em todos os containers:
  - **Traefik**: Porta corrigida de 80 para 8080 (porta interna real)
  - **Unbound**: Comando alterado de `nslookup` para `drill` (disponível no container)
  - **CrowdSec Bouncer**: Substituído `wget` por `nc -z` (netcat) para testar porta

### Added
- **Comando `make test-health`**: Health check detalhado com diagnósticos
- **Seção de healthchecks no README.md**: Documentação sobre monitoramento
- **Seção de troubleshooting**: Guia completo para resolver containers "unhealthy"
- **Guia de refazer stack**: Comandos para reconstruir ambiente do zero

### Improved
- **README.md**: Seção de comandos reorganizada e expandida
- **Makefile**: Help melhorado com descrição de `test-health`
- **TROUBLESHOOTING.md**: Adicionada seção detalhada sobre healthchecks

### Documentation
- Todos os healthchecks agora testam corretamente:
  - Traefik HTTP entrypoint (porta 8080)
  - Unbound DNS resolution (drill)
  - AdGuard web interface (porta 3000)
  - CrowdSec CLI (cscli version)
  - CrowdSec Bouncer TCP port (8080)

---

## [1.0.0] - 2026-04-29

### Initial Release
- Stack completa com Traefik, AdGuard, Unbound, CrowdSec
- Setup automatizado via `setup.sh`
- Makefile com comandos simplificados
- IPs estáticos para containers (resolução de DNS confiável)
- Configuração versionada do AdGuard Home
- SSL/TLS automático via Cloudflare DNS Challenge
- Resource limits para todos containers
- Healthchecks básicos (com bugs corrigidos posteriormente)
