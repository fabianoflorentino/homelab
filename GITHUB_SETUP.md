# GitHub Setup Instructions

## 1. Login no GitHub CLI
```bash
gh auth login
# Follow the interactive prompts (recommended: HTTPS + browser login)
```

## 2. Criar repositório e fazer push
```bash
# Criar repositório no GitHub (público)
gh repo create homelab --public --push --source=. --description "Homelab DNS stack with Traefik, AdGuard, Unbound, and CrowdSec"

# Ou se preferir repositório privado:
gh repo create homelab --private --push --source=. --description "Homelab DNS stack with Traefik, AdGuard, Unbound, and CrowdSec"
```

## 3. Verificar
```bash
git remote -v
git log --oneline
```

## Commits criados
- `8424514` feat: add base infrastructure with Traefik proxy and configuration files
- `d726760` feat: add Unbound DNS with DoT (DNS over TLS) and statistics
- `88efe97` feat: add AdGuardHome versioned configuration with malware blocking
- `b34239c` feat: configure CrowdSec to analyze AdGuard and Unbound logs
- `e2eba1e` feat: add automated setup script and Makefile for simplified management
