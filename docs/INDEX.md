# Índice de Documentação - Homelab Stack

Guia rápido de navegação pela documentação do projeto.

---

## 📋 Documentos Principais

### 🏠 [README.md](../README.md)
**Início rápido e visão geral**
- Arquitetura da stack
- Instalação automatizada e manual
- Comandos úteis (Makefile)
- Configuração básica

---

### 🔧 [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
**Solução de problemas comuns**
- ❌ Containers unhealthy
- 🔐 Reset de senha do AdGuard
- 🌐 Problemas de DNS (Unbound/AdGuard)
- 🔑 Erros de API Key do CrowdSec
- 📜 Erros de certificado SSL (Cloudflare)
- 🐛 Comandos de diagnóstico

**Quando usar**: Container não funciona, erro crítico, senha esquecida

---

### 🔐 [SECURITY.md](SECURITY.md)
**Segurança e autenticação**
- 🔑 Reset de senha (AdGuard, Traefik, CrowdSec)
- 🛡️ Melhores práticas de segurança
- 📋 Checklist de segurança pós-instalação
- 🔍 Auditoria e monitoramento de acessos
- 🔒 Acesso remoto seguro (VPN, SSH tunnels)
- 💾 Backup de credenciais

**Quando usar**: Gerenciar senhas, configurar segurança, auditoria

---

### 🌐 [DNS_REWRITES_EXAMPLES.md](DNS_REWRITES_EXAMPLES.md)
**DNS Rewrites - Nomes locais**
- 📝 Como configurar DNS rewrites
- 🎯 Exemplos práticos (homeserver.local, nas.local, etc.)
- 🌟 Wildcards para subdomínios
- 🔍 Testes e troubleshooting
- 🏷️ Evitar hairpin NAT

**Quando usar**: Acessar serviços por nome em vez de IP

---

### 📜 [CHANGELOG.md](../CHANGELOG.md)
**Histórico de mudanças**
- Todas as versões e melhorias
- Correções de bugs
- Novas funcionalidades
- Breaking changes

**Quando usar**: Ver o que mudou, comparar versões

---

## 🎯 Guias Rápidos por Tarefa

### 🚀 Primeira Instalação
1. [README.md - Instalação Rápida](../README.md#instalação-rápida-automatizada)
2. [README.md - Pré-requisitos](../README.md#pré-requisitos)
3. [SECURITY.md - Checklist Pós-Instalação](SECURITY.md#-checklist-de-segurança)

### 🔐 Resetar Senha
1. **AdGuard**: [SECURITY.md - Reset AdGuard](SECURITY.md#-adguard-home---gerenciamento-de-senha) ou [TROUBLESHOOTING.md](../TROUBLESHOOTING.md#problema-esqueci-a-senha-do-adguard-home)
2. **Traefik**: [SECURITY.md - Traefik Auth](SECURITY.md#-traefik---autenticação-http-basic)
3. **CrowdSec**: [SECURITY.md - CrowdSec API](SECURITY.md#-crowdsec---api-keys)

### 🛠️ Resolver Problemas
1. [TROUBLESHOOTING.md - Índice](../TROUBLESHOOTING.md)
2. Ver logs: `make logs` ou `docker compose logs -f [serviço]`
3. Health check: `make test-health`

### 🌐 Configurar DNS Local
1. [DNS_REWRITES_EXAMPLES.md](DNS_REWRITES_EXAMPLES.md)
2. Acesse: `http://IP:3000` → **Filters** → **DNS rewrites**
3. Adicione domínio e IP

### 🔄 Refazer Stack do Zero
1. [README.md - Refazer Stack](../README.md#-refazer-stack-completa)
2. Backup: `make backup`
3. Limpar: `make clean`
4. Setup: `make setup`
5. Subir: `make up`

### 📊 Monitoramento
1. **AdGuard Dashboard**: `http://IP:3000`
2. **Traefik Dashboard**: `http://IP:8080` (configurar rota)
3. **CrowdSec Métricas**: `make crowdsec cmd="metrics"`
4. **Health Check**: `make test-health`

---

## 🗂️ Estrutura de Arquivos

```
homelab/
├── README.md                    # Início rápido
├── TROUBLESHOOTING.md          # Solução de problemas
├── CHANGELOG.md                # Histórico de mudanças
├── docker-compose.yml          # Configuração dos containers
├── .env                        # Variáveis de ambiente (senhas, tokens)
├── Makefile                    # Comandos automatizados
├── setup.sh                    # Script de instalação
├── fix-permissions.sh          # Correção de permissões
│
├── docs/
│   ├── INDEX.md               # Este arquivo
│   ├── SECURITY.md            # Segurança e autenticação
│   ├── DNS_REWRITES_EXAMPLES.md  # Guia de DNS rewrites
│   └── configure.md           # Configurações detalhadas (legado)
│
├── traefik/
│   ├── traefik.yml            # Configuração principal
│   ├── acme/
│   │   └── acme.json          # Certificados SSL
│   └── dynamic/
│       └── *.yml              # Rotas e middlewares
│
├── adguard/
│   ├── conf/
│   │   └── AdGuardHome.yaml   # Configuração versionada
│   └── work/                  # Dados e logs
│
├── unbound/
│   └── unbound.conf           # DNS recursivo + DoT
│
└── crowdsec/
    ├── config/                # Configurações persistidas
    └── data/                  # Banco de dados de decisões
```

---

## 🔍 Encontrar Informação Rápida

### Por Serviço

| Serviço | Configuração | Troubleshooting | Segurança |
|---------|--------------|-----------------|-----------|
| **AdGuard** | [README](../README.md#8-configurar-adguard-home) | [TROUBLESHOOTING](../TROUBLESHOOTING.md#problema-adguard-não-consegue-conectar-ao-unbound) | [SECURITY](SECURITY.md#-adguard-home---gerenciamento-de-senha) |
| **Traefik** | [README](../README.md#7-subir-a-stack-completa) | [TROUBLESHOOTING](../TROUBLESHOOTING.md#problema-containers-marcados-como-unhealthy) | [SECURITY](SECURITY.md#-traefik---autenticação-http-basic) |
| **Unbound** | [README](../README.md#melhorias-implementadas) | [TROUBLESHOOTING](../TROUBLESHOOTING.md#problema-unbound-crashando-com-dot) | N/A |
| **CrowdSec** | [README](../README.md#6-subir-o-crowdsec-e-gerar-a-api-key-do-bouncer) | [TROUBLESHOOTING](../TROUBLESHOOTING.md#problema-crowdsec-api-key-não-gerada-no-setup) | [SECURITY](SECURITY.md#-crowdsec---api-keys) |

### Por Tipo de Problema

| Problema | Documento | Seção |
|----------|-----------|-------|
| Senha esquecida | [SECURITY.md](SECURITY.md) | Reset de Senha |
| Container unhealthy | [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) | Containers Unhealthy |
| DNS não resolve | [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) | AdGuard/Unbound |
| Erro de certificado | [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) | Token Cloudflare |
| Permissão negada | [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) | Permission Denied |
| Acesso por nome local | [DNS_REWRITES_EXAMPLES.md](DNS_REWRITES_EXAMPLES.md) | - |

---

## 🆘 Comandos Úteis

### Diagnóstico Rápido
```bash
make status        # Ver containers rodando
make test-health   # Health check detalhado
make logs          # Ver todos os logs
docker compose ps  # Status com health
```

### Logs de Serviço Específico
```bash
make logs-svc svc=adguardhome
make logs-svc svc=traefik
make logs-svc svc=unbound
make logs-svc svc=crowdsec
```

### Reiniciar Serviços
```bash
make restart                      # Todos
docker compose restart adguardhome  # Específico
```

### CrowdSec
```bash
make crowdsec cmd="alerts list"
make crowdsec cmd="decisions list"
make crowdsec cmd="bouncers list"
make crowdsec cmd="metrics"
```

---

## 📞 Suporte e Contribuição

### Reportar Problemas
1. Verificar [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
2. Executar: `make test-health` e copiar output
3. Coletar logs: `make logs > logs.txt`
4. Abrir issue no GitHub com logs e descrição

### Contribuir
1. Fork do repositório
2. Criar branch: `git checkout -b feature/nova-funcionalidade`
3. Commit: `git commit -m "feat: descrição"`
4. Push: `git push origin feature/nova-funcionalidade`
5. Abrir Pull Request

---

## 📚 Recursos Externos

### Documentação Oficial
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Traefik](https://doc.traefik.io/traefik/)
- [Unbound](https://nlnetlabs.nl/documentation/unbound/)
- [CrowdSec](https://docs.crowdsec.net/)

### Comunidade
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/homelab](https://reddit.com/r/homelab)
- [Docker Forums](https://forums.docker.com/)

---

## ✅ Checklist de Leitura Recomendada

Para novo usuário:
- [ ] Ler [README.md](../README.md) completo
- [ ] Seguir [Instalação Rápida](../README.md#instalação-rápida-automatizada)
- [ ] Completar [Checklist de Segurança](SECURITY.md#-checklist-de-segurança)
- [ ] Configurar [DNS Rewrites](DNS_REWRITES_EXAMPLES.md) (opcional)
- [ ] Bookmarkar [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

Para administrador experiente:
- [ ] Ler [SECURITY.md](SECURITY.md) - Melhores práticas
- [ ] Configurar backup automatizado
- [ ] Implementar monitoramento (Prometheus/Grafana)
- [ ] Configurar alertas (Discord, Telegram, email)
- [ ] Revisar logs periodicamente

---

**Última atualização**: 2024
**Versão da Stack**: 1.0
