# Configuração da Stack

Referência detalhada de configuração de cada ferramenta do homelab.

---

## Traefik

### Arquivo principal — `traefik/traefik.yml`

```yaml
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false   # serviços só são expostos com label traefik.enable=true
  file:
    directory: /etc/traefik/dynamic
    watch: true               # recarrega arquivos dinâmicos sem reiniciar

certificatesResolvers:
  cloudflare:
    acme:
      email: seu-email@dominio.com   # substituir pelo e-mail real
      storage: /acme/acme.json
      dnsChallenge:
        provider: cloudflare         # usa API da Cloudflare para DNS-01 challenge

accessLog:
  filePath: /var/log/traefik-access.log  # lido pelo CrowdSec

log:
  level: INFO
```

**O que configurar:**
- `email` — seu e-mail para o Let's Encrypt
- O arquivo `traefik/acme/acme.json` deve existir com permissão `600` antes de subir

---

### Dashboard — `traefik/dynamic/dashboard.yml`

```yaml
http:
  routers:
    traefik-dashboard:
      rule: "Host(`traefik.seudominio.com`)"   # substituir pelo seu domínio
      service: api@internal
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare
      middlewares:
        - dashboard-auth
        - dashboard-ratelimit
        - dashboard-ipwhitelist
        - security-headers
```

**O que configurar:**
- `traefik.seudominio.com` → seu subdomínio real (ex: `traefik.meudominio.com.br`)
- Os middlewares de autenticação, rate limit e whitelist são definidos em `middlewares.yml`

---

### Middlewares — `traefik/dynamic/middlewares.yml`

```yaml
http:
  middlewares:
    redirect-https:
      redirectScheme:
        scheme: https
        permanent: true           # redireciona HTTP → HTTPS para todos os serviços

    security-headers:
      headers:
        frameDeny: true
        browserXssFilter: true
        contentTypeNosniff: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        forceSTSHeader: true      # força HSTS

    dashboard-auth:
      basicAuth:
        users:
          - "admin:$apr1$CHANGE_ME"   # substituir pelo hash gerado com htpasswd

    dashboard-ratelimit:
      rateLimit:
        average: 20               # requisições por segundo permitidas
        burst: 50                 # pico máximo

    dashboard-ipwhitelist:
      ipAllowList:
        sourceRange:
          - "192.168.1.0/24"      # ajustar para sua faixa de rede local
```

**O que configurar:**
- Hash de senha: gere com `htpasswd -nb admin SUA_SENHA_FORTE` e substitua `admin:$apr1$CHANGE_ME`
- `sourceRange` do whitelist: ajuste para o CIDR da sua rede local

**Como expor um novo serviço via Traefik:**

Adicione labels ao serviço no `docker-compose.yml`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.meuservico.rule=Host(`meuservico.meudominio.com.br`)"
  - "traefik.http.routers.meuservico.entrypoints=websecure"
  - "traefik.http.routers.meuservico.tls.certresolver=cloudflare"
  - "traefik.http.routers.meuservico.middlewares=redirect-https,security-headers"
  - "traefik.http.services.meuservico.loadbalancer.server.port=PORTA_INTERNA"
```

---

## Unbound

### Arquivo — `unbound/unbound.conf`

```yaml
server:
  verbosity: 1
  interface: 0.0.0.0
  port: 53

  do-ip4: yes
  do-udp: yes
  do-tcp: yes

  harden-glue: yes                     # rejeita registros fora da delegação
  harden-dnssec-stripped: yes          # rejeita respostas sem assinatura DNSSEC
  harden-large-queries: yes            # protege contra amplificação DNS

  prefetch: yes                        # pré-carrega entradas populares antes de expirar
  qname-minimisation: yes              # envia o mínimo de informação possível aos resolvers raiz

  cache-max-ttl: 86400                 # TTL máximo em cache: 24h
  cache-min-ttl: 300                   # TTL mínimo em cache: 5min

  auto-trust-anchor-file: "/var/lib/unbound/root.key"   # DNSSEC via root anchor
```

**Comportamento:**
- O Unbound é um **resolver recursivo**: consulta os servidores raiz diretamente, sem usar resolvers externos como `8.8.8.8`
- Exposto na porta `5335` do host (mapeada internamente como `53` dentro do container)
- O AdGuard Home aponta para `IP_DO_SERVIDOR:5335` como upstream

**Ajustes opcionais:**

```conf
# Adicionar zonas privadas (evita vazamento de DNS local)
private-domain: "home.arpa"
local-zone: "home.arpa" static

# Limitar acesso apenas à rede local
access-control: 127.0.0.1/32 allow
access-control: 192.168.1.0/24 allow
access-control: 0.0.0.0/0 refuse
```

---

## AdGuard Home

O AdGuard Home é configurado via interface web em `http://IP_DO_SERVIDOR:3000`.

### Upstream DNS

**Settings → DNS Settings → Upstream DNS Servers**

```
IP_DO_SERVIDOR:5335
```

Isso direciona todas as consultas DNS para o Unbound local.

### DNS Rewrites (entradas locais)

**Filters → DNS Rewrites**

Use para resolver hostnames da rede interna:

```
nas.home.arpa        → 192.168.1.10
portainer.home.arpa  → 192.168.1.20
jellyfin.home.arpa   → 192.168.1.30
```

### Listas de bloqueio sugeridas

**Filters → DNS Blocklists → Add blocklist**

| Lista | URL |
|---|---|
| AdGuard DNS filter | `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt` |
| EasyList | `https://easylist.to/easylist/easylist.txt` |
| Peter Lowe's list | `https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus` |

### Bootstrap DNS

**Settings → DNS Settings → Bootstrap DNS Servers**

```
1.1.1.1
9.9.9.9
```

Usado apenas para resolver o endereço do upstream na inicialização.

---

## CrowdSec

### Aquisição de logs — `crowdsec/acquis.yaml`

```yaml
filenames:
  - /var/log/traefik-access.log   # arquivo de log lido pelo CrowdSec
labels:
  type: traefik                   # parser utilizado para interpretar o formato
```

O Traefik grava logs de acesso em `/var/log/traefik-access.log`, que é montado como volume somente leitura tanto no container do Traefik quanto no do CrowdSec.

### Collections instaladas

Definidas no `docker-compose.yml`:

```yaml
COLLECTIONS: >
  crowdsecurity/linux
  crowdsecurity/traefik
```

- `crowdsecurity/linux` — parsers e cenários gerais para Linux
- `crowdsecurity/traefik` — detecta brute force, scans e abusos via logs do Traefik

### Gerenciar o CrowdSec

```bash
# Ver alertas ativos
docker exec crowdsec cscli alerts list

# Ver IPs banidos
docker exec crowdsec cscli decisions list

# Banir manualmente um IP
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --reason "manual ban" --duration 24h

# Remover ban
docker exec crowdsec cscli decisions delete --ip 1.2.3.4

# Ver bouncers registrados
docker exec crowdsec cscli bouncers list

# Ver status das collections
docker exec crowdsec cscli collections list
```

### Bouncer (integração com Traefik)

O `crowdsec-bouncer` intercepta requisições no Traefik e consulta a API do CrowdSec para verificar se o IP está bloqueado.

Configuração no `docker-compose.yml`:

```yaml
crowdsec-bouncer:
  environment:
    CROWDSEC_BOUNCER_API_KEY: SUA_CHAVE_AQUI   # gerada com: cscli bouncers add traefik-bouncer
    CROWDSEC_AGENT_HOST: crowdsec:8080
```

Para o Traefik usar o bouncer como middleware, adicione ao arquivo dinâmico:

```yaml
# traefik/dynamic/middlewares.yml
http:
  middlewares:
    crowdsec-bouncer:
      forwardAuth:
        address: http://crowdsec-bouncer:8080/api/v1/forwardAuth
        trustForwardHeader: true
```

E inclua `crowdsec-bouncer` nos middlewares dos roteadores desejados.

---

## Variáveis de ambiente — `.env`

```env
CF_DNS_API_TOKEN=SEU_TOKEN_AQUI
```

| Variável | Descrição |
|---|---|
| `CF_DNS_API_TOKEN` | Token da API da Cloudflare com permissões DNS Edit + Zone Read. Usado pelo Traefik para validar certificados via DNS-01 challenge. |

---

## Backup

Arquivos e diretórios essenciais para backup:

| Caminho | Conteúdo |
|---|---|
| `traefik/acme/acme.json` | Certificados TLS emitidos pelo Let's Encrypt |
| `adguard/work/` | Banco de dados e estado do AdGuard Home |
| `adguard/conf/` | Configurações do AdGuard Home |
| `crowdsec/data/` | Banco de dados do CrowdSec (decisões, alertas) |
| `.env` | Credenciais e tokens |

Ferramentas sugeridas: [Restic](https://restic.net/) ou [BorgBackup](https://www.borgbackup.org/).

---

## Hardening

- Libere apenas as portas `22`, `53`, `80` e `443` no firewall do servidor
- Bloqueie a saída DNS (porta `53`) para os clientes da rede, forçando o uso do AdGuard Home
- O IP whitelist do dashboard Traefik deve apontar apenas para a rede interna
- O arquivo `acme.json` deve ter permissão `600` (somente o dono pode ler/escrever)
- O socket do Docker é montado somente leitura (`:ro`) no Traefik

---

## Próximos passos

Serviços adicionais que podem ser expostos via Traefik com TLS automático:

- **Portainer** — gerenciamento visual de containers
- **Jellyfin** — servidor de mídia
- **Grafana + Prometheus** — monitoramento e métricas
- **Authelia** ou **Authentik** — SSO com MFA para todos os serviços
