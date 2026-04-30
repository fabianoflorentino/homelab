# DNS Rewrites - Exemplos de Configuração

DNS Rewrites permitem resolver nomes locais para IPs da sua rede, sem precisar de um servidor DNS local adicional.

---

## 🎯 Como Funciona

Quando você acessa `homeserver.local`, o AdGuard responde diretamente com o IP configurado, sem consultar a internet.

---

## 📝 Exemplos de Uso

### 1. Via Interface Web (Mais Fácil)

Acesse: `http://192.168.0.100:3000` → **Filters** → **DNS rewrites**

Adicione os seguintes rewrites:

| Domain | IP | Uso |
|--------|-----|-----|
| `homeserver.local` | `192.168.0.100` | Servidor principal |
| `adguard.local` | `192.168.0.100` | AdGuard dashboard |
| `traefik.local` | `192.168.0.100` | Traefik dashboard |
| `router.local` | `192.168.0.1` | Seu roteador |

---

### 2. Via Arquivo de Configuração

Edite `adguard/conf/AdGuardHome.yaml` no servidor:

```yaml
dns:
  # ... outras configurações ...
  rewrites:
    - domain: homeserver.local
      answer: 192.168.0.100
    - domain: adguard.local
      answer: 192.168.0.100
    - domain: traefik.local
      answer: 192.168.0.100
    - domain: router.local
      answer: 192.168.0.1
    - domain: nas.local
      answer: 192.168.0.50
    - domain: pi.local
      answer: 192.168.0.200
```

Depois reinicie o AdGuard:
```bash
docker compose restart adguardhome
```

---

## 🌐 Wildcards (Subdomínios)

Para criar um wildcard que resolve TODOS os subdomínios:

```yaml
rewrites:
  - domain: "*.home.local"
    answer: 192.168.0.100
```

Agora você pode acessar:
- `traefik.home.local` → 192.168.0.100
- `adguard.home.local` → 192.168.0.100
- `qualquercoisa.home.local` → 192.168.0.100

---

## 🚀 Casos de Uso Avançados

### 1. Serviços Docker com Traefik

Se você tem serviços Docker expostos via Traefik:

```yaml
rewrites:
  - domain: portainer.fabianoflorentino.dev
    answer: 192.168.0.100
  - domain: grafana.fabianoflorentino.dev
    answer: 192.168.0.100
  - domain: jellyfin.fabianoflorentino.dev
    answer: 192.168.0.100
```

Depois configure rotas no Traefik para cada serviço.

---

### 2. Múltiplos Servidores

```yaml
rewrites:
  - domain: server1.local
    answer: 192.168.0.100
  - domain: server2.local
    answer: 192.168.0.101
  - domain: nas.local
    answer: 192.168.0.50
  - domain: backup.local
    answer: 192.168.0.75
```

---

### 3. Resolução Local de Domínio Público

Útil para forçar resolução local quando você acessa seu domínio de dentro da rede:

```yaml
rewrites:
  - domain: fabianoflorentino.dev
    answer: 192.168.0.100
  - domain: "*.fabianoflorentino.dev"
    answer: 192.168.0.100
```

Isso evita "hairpin NAT" - acessar seu servidor via IP público quando está na mesma rede.

---

## 🧪 Testar Rewrites

Depois de configurar, teste:

```bash
# Windows
nslookup homeserver.local 192.168.0.100

# Linux/Mac
dig @192.168.0.100 homeserver.local

# Ou simplesmente no navegador
http://homeserver.local
```

---

## ⚠️ Dicas Importantes

1. **Use domínios `.local`** para evitar conflito com domínios reais
2. **Ou use `.home.arpa`** (padrão RFC para redes locais)
3. **Evite conflito** com nomes já existentes na internet
4. **Reinicie o AdGuard** após editar manualmente o arquivo
5. **Limpe o cache DNS** do seu PC após mudanças:
   - Windows: `ipconfig /flushdns`
   - Linux: `sudo systemd-resolve --flush-caches`
   - Mac: `sudo dscacheutil -flushcache`

---

## 📊 Monitoramento

Veja as queries no dashboard do AdGuard:
- Acesse: `http://192.168.0.100:3000`
- Vá em: **Query Log**
- Filtre por: `homeserver.local` (ou outro domínio configurado)

Você verá as resoluções locais acontecendo em tempo real!

---

## 🔐 Exemplo Completo para Homelab

```yaml
dns:
  rewrites:
    # Servidor principal
    - domain: homeserver.local
      answer: 192.168.0.100
    
    # Serviços no homeserver
    - domain: adguard.local
      answer: 192.168.0.100
    - domain: traefik.local
      answer: 192.168.0.100
    - domain: portainer.local
      answer: 192.168.0.100
    
    # Outros dispositivos
    - domain: nas.local
      answer: 192.168.0.50
    - domain: router.local
      answer: 192.168.0.1
    - domain: printer.local
      answer: 192.168.0.25
    
    # Wildcard para domínio público (evita hairpin NAT)
    - domain: "*.fabianoflorentino.dev"
      answer: 192.168.0.100
  
  rewrites_enabled: true
```

Salve e reinicie:
```bash
cd ~/homelab
docker compose restart adguardhome
```

Agora você pode acessar seus serviços por nomes amigáveis! 🎉
