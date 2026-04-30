# Troubleshooting - Homelab Stack

## Problema: Token Cloudflare com erro "Cannot use the access token from location: IP"

### Causa
O token Cloudflare está restrito a IPs específicos ou tem restrições de uso.

### Solução

1. **Acesse o painel da Cloudflare**: https://dash.cloudflare.com/profile/api-tokens

2. **Localize o token** criado anteriormente e clique em "Edit"

3. **Verifique as restrições de IP**:
   - Na seção "IP Address Filtering"
   - Se houver IPs listados, **adicione o IP do seu servidor homelab**
   - Ou **remova todas as restrições de IP** (menos seguro, mas funciona)

4. **Verifique as permissões**:
   ```
   Zone:DNS:Edit
   Zone:Zone:Read
   ```

5. **Zone Resources** deve incluir:
   - Include → Specific zone → fabianoflorentino.dev

6. **Salve** o token e **atualize** no arquivo `.env`:
   ```bash
   nano .env
   # Atualize CF_DNS_API_TOKEN=seu_novo_token
   ```

7. **Reinicie o Traefik**:
   ```bash
   make restart
   # ou
   docker compose restart traefik
   ```

8. **Verifique os logs**:
   ```bash
   docker compose logs traefik | grep -i cloudflare
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
Containers em redes Docker diferentes não conseguem resolver nomes.

### Solução ✅ (Aplicada)

Ambos containers agora estão nas redes `dns` e `proxy`:

```yaml
adguardhome:
  networks:
    - dns
    - proxy

unbound:
  networks:
    - dns
    - proxy
```

E o upstream DNS foi configurado como:
```yaml
upstream_dns:
  - unbound:53
```

### Verificar conectividade

```bash
# Entrar no container AdGuard
docker exec -it adguardhome sh

# Testar resolução do Unbound
nslookup google.com unbound

# Testar ping (se disponível)
ping -c 3 unbound
```

---

## Problema: CrowdSec API Key não gerada no setup

### Sintoma
```
make: *** [Makefile:23: setup] Error 1
```

### Causa
Bouncer já existe ou CrowdSec não está pronto.

### Solução ✅ (Aplicada)

O script `setup.sh` foi atualizado para:
1. Deletar bouncer existente (se houver)
2. Criar novo bouncer
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
