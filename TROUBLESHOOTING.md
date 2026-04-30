# Troubleshooting - Homelab Stack

## 🔴 ERRO CRÍTICO: AdGuard com "permission denied" no leases.json

### Sintoma
```
[fatal] initing dhcp: loading db: reading db: open /opt/adguardhome/work/data/leases.json: permission denied
```

Container reiniciando constantemente.

### Causa
Arquivos no diretório `adguard/work` foram criados como root, mas o container AdGuard roda com `user: "1000:1000"`.

### Solução Rápida ✅

Execute no servidor:

```bash
cd ~/homelab

# Use o script de correção automática
chmod +x fix-permissions.sh
./fix-permissions.sh

# Ou manualmente:
docker compose down
sudo chown -R $USER:$USER adguard/work adguard/conf traefik/acme
chmod 600 traefik/acme/acme.json
docker compose up -d
```

**IMPORTANTE**: Se o problema persistir, delete os dados e reconfigure:

```bash
docker compose down
rm -rf adguard/work/*
mkdir -p adguard/work/data adguard/work/log
sudo chown -R $USER:$USER adguard/
docker compose up -d
# Acesse http://IP_SERVIDOR:3000 para configurar
```

---

## Problema: Token Cloudflare com erro "Cannot use the access token from location: IP"

### Causa
O token Cloudflare está restrito a IPs específicos.

### ⚠️ Solução Obrigatória

**O erro mostra que seu IP público está tentando usar o token mas não está autorizado.**

Você **DEVE** fazer uma destas opções:

#### Opção 1: Remover Restrições de IP (Recomendado para homelab)

1. Acesse: https://dash.cloudflare.com/profile/api-tokens
2. Clique em **Edit** no seu token API
3. Vá para **IP Address Filtering**
4. **Delete todos os IPs** da lista (deixe em branco)
5. Clique em **Continue to summary** → **Save**
6. **Não precisa gerar novo token!** O mesmo token agora funcionará sem restrições

#### Opção 2: Adicionar IP do Servidor

1. Descubra o IP público do servidor:
   ```bash
   curl -4 ifconfig.me
   ```
2. Na Cloudflare, **IP Address Filtering** → **Add**
3. Adicione o IP retornado
4. Salve

#### Depois de corrigir na Cloudflare:

```bash
# Não precisa mudar .env (token é o mesmo)
# Apenas reinicie o Traefik
docker compose restart traefik

# Verifique se funcionou
docker compose logs traefik | grep -i certificate
```

### Alternativa: Criar novo token sem restrições

1. No painel Cloudflare: **Create Token → Custom token**
2. Configurar permissões:
   - **Zone:DNS:Edit**
   - **Zone:Zone:Read**
3. **Zone Resources**: Include → Specific zone → fabianoflorentino.dev
4. **IP Address Filtering**: Deixe em branco (sem restrições)
5. Copie o token e atualize o `.env`

---

## Problema: AdGuard não consegue conectar ao Unbound

### Sintoma
```
dialing unbound:53 over udp: no addresses
```

### Causa
Docker não resolve hostnames corretamente quando containers estão em múltiplas redes bridge customizadas.

### Solução ✅ (Aplicada)

**Configurado IPs fixos** para garantir conectividade confiável:

```yaml
# docker-compose.yml
networks:
  dns:
    ipam:
      config:
        - subnet: 172.18.0.0/16
  proxy:
    ipam:
      config:
        - subnet: 172.20.0.0/16

unbound:
  networks:
    dns:
      ipv4_address: 172.18.0.10  # IP fixo
    proxy:
      ipv4_address: 172.20.0.10

# AdGuardHome.yaml
upstream_dns:
  - 172.18.0.10:53  # Unbound (IP fixo)
```

### Verificar conectividade

```bash
# Testar se AdGuard consegue resolver via Unbound
docker exec adguardhome nslookup google.com 172.18.0.10

# Ver logs do AdGuard para erros
docker compose logs adguardhome | grep -i error
```

---

## Problema: CrowdSec API Key não gerada no setup

### Sintoma
```
make: *** [Makefile:23: setup] Error 1
```
Ou logs mostrando:
```
rsync: Permission denied (13)
```

### Causa
1. Bouncer já existe
2. CrowdSec não está pronto
3. **Permissões incorretas**: CrowdSec precisa rodar como root para criar arquivos de configuração

### Solução ✅ (Aplicada)

**Atualização importante**: CrowdSec agora roda como root (removido `user: "1000:1000"`) porque precisa criar arquivos de configuração no `/etc/crowdsec`. Isso é seguro porque o container está isolado.

O script `setup.sh` foi atualizado para:
1. Criar diretório `crowdsec/config` para persistir configurações
2. Deletar bouncer existente (se houver)
3. Criar novo bouncer
4. Verificar se foi criado com sucesso

### Limpeza e regeneração

Se continuar com erro, faça limpeza completa:

```bash
# Parar todos os containers
docker compose down

# Remover dados do CrowdSec (CUIDADO: apaga configurações!)
rm -rf crowdsec/data/* crowdsec/config/*

# Recriar estrutura
mkdir -p crowdsec/data crowdsec/config

# Rodar setup novamente
make setup
```
3. Verificar se foi criado com sucesso

### Gerar manualmente

```bash
# Deletar bouncer existente (se necessário)
docker exec crowdsec cscli bouncers delete traefik-bouncer

# Gerar nova chave
docker exec crowdsec cscli bouncers add traefik-bouncer -o raw

# Copie a chave gerada e atualize docker-compose.yml:
nano docker-compose.yml
# Procure por CROWDSEC_BOUNCER_API_KEY e substitua
```

---

## Problema: Unbound crashando com DoT

### Sintoma
```
unbound[1:0] error: SSL handshake failed
```

### Causa
`forward-tls-upstream: yes` causando problemas de conectividade.

### Solução (Temporária)

DoT foi desabilitado no Unbound para estabilização:

```yaml
forward-zone:
  name: "."
  forward-addr: 9.9.9.9        # Quad9
  forward-addr: 149.112.112.112 # Quad9 secundário
  # forward-tls-upstream: yes  # DESABILITADO
```

### Reativar DoT (Após estabilização)

```bash
nano unbound/unbound.conf

# Adicionar:
forward-tls-upstream: yes
forward-addr: 9.9.9.9@853
forward-addr: 149.112.112.112@853

# Reiniciar
docker compose restart unbound
docker compose logs -f unbound
```

---

## Problema: Containers marcados como "unhealthy"

### Sintoma
```bash
docker compose ps
# Mostra containers como "unhealthy" mas eles estão funcionando
```

### Causa
Healthchecks configurados incorretamente - usando comandos que não existem nos containers ou portas erradas.

### Solução ✅ (Aplicada)

Os healthchecks foram corrigidos em `docker-compose.yml`:

#### Traefik
```yaml
# ANTES (errado - porta 80 não existe)
test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:80"]

# DEPOIS (correto - porta 8080 interna)
test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080"]
```

#### Unbound
```yaml
# ANTES (errado - nslookup não existe no container)
test: ["CMD", "nslookup", "google.com", "127.0.0.1", "-p", "53"]

# DEPOIS (correto - drill está disponível)
test: ["CMD", "drill", "google.com", "@127.0.0.1"]
```

#### CrowdSec Bouncer
```yaml
# ANTES (errado - wget não existe no container)
test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/ping"]

# DEPOIS (correto - netcat para testar porta)
test: ["CMD", "sh", "-c", "nc -z localhost 8080 || exit 1"]
```

### Aplicar correções

Se você ainda tem a versão antiga do `docker-compose.yml`:

```bash
# Fazer backup
cp docker-compose.yml docker-compose.yml.backup

# Baixar versão atualizada do repositório
git pull

# Ou editar manualmente conforme acima

# Recriar containers com novos healthchecks
docker compose up -d --force-recreate

# Verificar status (aguarde ~30s)
docker compose ps
```

### Verificar saúde dos serviços

```bash
# Ver status resumido
make health

# Ver detalhes completos
docker compose ps

# Ver logs de healthcheck de um container específico
docker inspect traefik --format '{{json .State.Health}}' | jq
```

---

## Comandos úteis de diagnóstico

### Ver logs de todos os serviços
```bash
make logs
```

### Ver logs de um serviço específico
```bash
docker compose logs -f traefik
docker compose logs -f adguardhome
docker compose logs -f unbound
docker compose logs -f crowdsec
```

### Status dos containers
```bash
make status
# ou
docker compose ps
```

### Health check
```bash
make health
```

### Testar DNS manualmente

```bash
# Testar AdGuard (porta 5301)
dig @localhost -p 5301 google.com

# Testar Unbound (porta 5300)
dig @localhost -p 5300 google.com

# Testar com nslookup
nslookup google.com 127.0.0.1 -port=5301
```

### Verificar certificados TLS

```bash
# Ver certificados gerados
cat traefik/acme/acme.json | jq

# Logs de geração de certificados
docker compose logs traefik | grep -i acme
docker compose logs traefik | grep -i certificate
```

### CrowdSec - Ver alertas

```bash
make crowdsec cmd="alerts list"

# Ver bouncers ativos
make crowdsec cmd="bouncers list"

# Ver métricas
make crowdsec cmd="metrics"
```

---

## Portas utilizadas

| Serviço | Porta Host | Porta Container | Protocolo |
|---------|-----------|----------------|-----------|
| Traefik (HTTP) | 8080 | 80 | TCP |
| Traefik (HTTPS) | 8443 | 443 | TCP |
| AdGuard (DNS) | 5301 | 53 | TCP/UDP |
| AdGuard (Web UI) | 3000 | 3000 | TCP |
| AdGuard (Metrics) | 9617 | 9617 | TCP |
| Unbound (DNS) | 5300 | 53 | TCP/UDP |

**Nota**: CasaOS usa portas 80 e 443, por isso Traefik usa 8080 e 8443.

---

## Resetar configuração

### Reset completo (CUIDADO!)

```bash
make down
sudo rm -rf traefik/acme/* crowdsec/data/* adguard/work/* adguard/conf/*
cp adguard/conf/AdGuardHome.yaml.backup adguard/conf/AdGuardHome.yaml
make setup
```

### Reset apenas certificados

```bash
make down
rm traefik/acme/acme.json
echo "{}" > traefik/acme/acme.json
chmod 600 traefik/acme/acme.json
make up
```
