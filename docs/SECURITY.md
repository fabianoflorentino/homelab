# Segurança e Autenticação - Homelab Stack

Guia de gerenciamento de senhas, autenticação e segurança dos serviços.

---

## 🔐 AdGuard Home - Gerenciamento de Senha

### Login Padrão (Primeira Instalação)

Após instalação inicial:
- **URL**: `http://IP_SERVIDOR:3000`
- **Usuário**: `admin`
- **Senha**: Configure no primeiro acesso

### Resetar Senha Esquecida

#### Método 1: Resetar via Arquivo de Configuração ⭐ (Recomendado)

```bash
# 1. Parar o AdGuard
docker compose stop adguardhome

# 2. Fazer backup da configuração
cp adguard/conf/AdGuardHome.yaml adguard/conf/AdGuardHome.yaml.backup

# 3. Editar o arquivo
nano adguard/conf/AdGuardHome.yaml

# 4. Procurar pela seção 'users:' e limpar a senha:
# ANTES:
# users:
#   - username: admin
#     password: "$2a$10$hash_bcrypt_aqui..."
#
# DEPOIS:
# users:
#   - username: admin
#     password: ""

# 5. Salvar (Ctrl+O, Enter, Ctrl+X) e reiniciar
docker compose up -d adguardhome

# 6. Acessar e configurar nova senha
http://192.168.0.100:3000
```

#### Método 2: Gerar Nova Senha Manualmente

```bash
# 1. Gerar hash bcrypt da nova senha
docker run --rm alpine sh -c "apk add --no-cache bcrypt-tool && htpasswd -nbBC 10 admin NOVA_SENHA_AQUI | cut -d: -f2"

# Exemplo com senha "admin123":
docker run --rm alpine sh -c "apk add --no-cache bcrypt-tool && htpasswd -nbBC 10 admin admin123 | cut -d: -f2"

# 2. Copiar o hash gerado (começa com $2y$10$...)

# 3. Parar o AdGuard
docker compose stop adguardhome

# 4. Editar configuração
nano adguard/conf/AdGuardHome.yaml

# 5. Substituir a senha pelo novo hash:
users:
  - username: admin
    password: "$2y$10$HASH_COPIADO_AQUI"

# 6. Reiniciar
docker compose up -d adguardhome

# 7. Fazer login com nova senha
```

#### Método 3: Reset Completo (⚠️ Perde todas as configurações)

```bash
# 1. Parar tudo
docker compose down

# 2. Backup completo (opcional)
tar -czf adguard-backup-$(date +%F).tar.gz adguard/

# 3. Remover dados
rm -rf adguard/work/*
rm adguard/conf/AdGuardHome.yaml

# 4. Recriar estrutura
mkdir -p adguard/work/data adguard/work/log
mkdir -p adguard/conf

# 5. Copiar configuração base
cp adguard/conf/AdGuardHome.yaml.template adguard/conf/AdGuardHome.yaml

# 6. Corrigir permissões
sudo chown -R $USER:$USER adguard/

# 7. Subir novamente
docker compose up -d

# 8. Acessar e fazer setup inicial
http://192.168.0.100:3000
```

### Alterar Senha (Logado)

Se você está logado e quer trocar a senha:

1. Acesse: `http://IP:3000`
2. Vá em: **Settings → General Settings**
3. Seção **Authentication**
4. Clique em **Change password**
5. Digite a senha atual e a nova senha
6. Salve

### Verificar Configuração de Usuário

```bash
# Ver configuração atual (sem mostrar senha)
grep -A2 "users:" adguard/conf/AdGuardHome.yaml

# Ver se o container está rodando
docker compose ps adguardhome

# Ver logs
docker compose logs adguardhome | tail -20
```

---

## 🔐 Traefik - Autenticação HTTP Basic

### Configuração Atual

O Traefik dashboard usa **HTTP Basic Auth** com:
- **Usuário**: `admin`
- **Senha**: Configurada no `.env` (variável `TRAEFIK_PASSWORD`)

### Gerar Nova Senha

```bash
# 1. Gerar hash da senha
echo $(htpasswd -nbB admin "SUA_SENHA_AQUI") | sed -e 's/\$/\$\$/g'

# Exemplo com senha "senhaforte123":
echo $(htpasswd -nbB admin "senhaforte123") | sed -e 's/\$/\$\$/g'

# 2. Copiar output (admin:$$2y$$...)

# 3. Editar .env
nano .env

# 4. Substituir TRAEFIK_PASSWORD
TRAEFIK_PASSWORD=admin:$$2y$$05$$...

# 5. Reiniciar Traefik
docker compose restart traefik
```

### Desabilitar Autenticação (Não Recomendado)

Para remover autenticação do dashboard:

```bash
# Editar traefik/traefik.yml
nano traefik/traefik.yml

# Remover ou comentar a seção:
# http:
#   middlewares:
#     auth:
#       basicAuth:
#         users:
#           - "${TRAEFIK_PASSWORD}"

# E remover o middleware das rotas em traefik/dynamic/dashboard.yml
```

---

## 🔐 CrowdSec - API Keys

### Listar Bouncers Ativos

```bash
docker exec crowdsec cscli bouncers list
```

### Gerar Nova API Key

```bash
# 1. Deletar bouncer antigo (se existir)
docker exec crowdsec cscli bouncers delete traefik-bouncer

# 2. Criar novo bouncer
docker exec crowdsec cscli bouncers add traefik-bouncer -o raw

# 3. Copiar a chave gerada

# 4. Atualizar docker-compose.yml
nano docker-compose.yml

# Procurar por:
# crowdsec-bouncer:
#   environment:
#     CROWDSEC_BOUNCER_API_KEY: "NOVA_CHAVE_AQUI"

# 5. Reiniciar bouncer
docker compose restart crowdsec-bouncer
```

### Verificar Conectividade

```bash
# Ver logs do bouncer
docker compose logs crowdsec-bouncer | tail -20

# Ver métricas
docker exec crowdsec cscli metrics
```

---

## 🛡️ Melhores Práticas de Segurança

### Senhas Fortes

✅ **Recomendado:**
- Mínimo 12 caracteres
- Mistura de letras, números e símbolos
- Sem palavras do dicionário
- Usar gerenciador de senhas (Bitwarden, 1Password, KeePass)

❌ **Evitar:**
- Senhas simples: `admin`, `password`, `123456`
- Informações pessoais: nome, data de nascimento
- Sequências: `abcd1234`, `qwerty`

### Exemplo de Senha Forte

```bash
# Gerar senha aleatória segura (Linux/Mac)
openssl rand -base64 24

# Exemplo de output:
# dKj9mP2xQ7vB8nL4wZ1rY6sA5hT3
```

### Backup de Configurações

```bash
# Backup completo do homelab
tar -czf homelab-backup-$(date +%F).tar.gz \
  adguard/conf/ \
  traefik/acme/ \
  crowdsec/data/ \
  .env \
  docker-compose.yml

# Armazenar em local seguro (NAS, cloud criptografado, etc.)
```

### Rotação de Credenciais

Recomenda-se trocar senhas periodicamente:
- **AdGuard**: A cada 90 dias
- **Traefik**: A cada 90 dias
- **CrowdSec API Keys**: A cada 180 dias ou após suspeita de comprometimento

### Proteção do Arquivo .env

```bash
# Garantir permissões restritas
chmod 600 .env

# Nunca commitar o .env no git
echo ".env" >> .gitignore

# Criar template sem valores sensíveis
cp .env .env.example
nano .env.example  # Remover valores reais
```

---

## 🔒 Acesso Remoto Seguro

### Não Expor Interfaces de Administração

❌ **Evite expor diretamente:**
- AdGuard Web UI (porta 3000)
- Traefik Dashboard (porta 8080)
- Portainer (se usar)

✅ **Use:**
- VPN (WireGuard, Tailscale)
- SSH Tunnel
- Cloudflare Access (Zero Trust)

### SSH Tunnel para Acesso Seguro

```bash
# No seu computador, criar túnel SSH:
ssh -L 3000:localhost:3000 usuario@IP_SERVIDOR

# Acessar localmente:
http://localhost:3000  # AdGuard
```

### Firewall - Bloquear Portas de Admin

```bash
# Permitir apenas SSH e DNS
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 53/tcp    # DNS
sudo ufw allow 53/udp    # DNS
sudo ufw deny 3000/tcp   # Bloquear AdGuard web UI da internet
sudo ufw deny 8080/tcp   # Bloquear Traefik dashboard
sudo ufw enable
```

---

## 🔍 Auditoria e Monitoramento

### Logs de Autenticação do AdGuard

```bash
# Ver tentativas de login
docker compose logs adguardhome | grep -i "auth\|login\|password"

# Ver acessos à interface web
docker compose logs adguardhome | grep "GET /"
```

### Logs do Traefik

```bash
# Ver acessos ao dashboard
docker compose logs traefik | grep -i "dashboard\|auth"

# Ver tentativas de autenticação falhadas
docker compose logs traefik | grep "401"
```

### CrowdSec - Monitorar Ataques

```bash
# Ver alertas de segurança
docker exec crowdsec cscli alerts list

# Ver IPs banidos
docker exec crowdsec cscli decisions list

# Ver tentativas de brute force
docker exec crowdsec cscli alerts list -t crowdsecurity/http-bruteforce
```

---

## 📋 Checklist de Segurança

Após instalação, verifique:

- [ ] Senha forte configurada no AdGuard
- [ ] Senha forte configurada no Traefik
- [ ] Arquivo `.env` com permissões `600`
- [ ] `.env` incluído no `.gitignore`
- [ ] Backup das configurações criado
- [ ] Portas de admin não expostas à internet
- [ ] Firewall configurado (ufw/iptables)
- [ ] Logs de autenticação monitorados
- [ ] CrowdSec operacional e bouncers conectados
- [ ] Certificados SSL renovando automaticamente
- [ ] DNS rewrites configurados (se usar)

---

## 🆘 Problemas Comuns

### "Senha incorreta" após resetar

**Causa**: Cache do navegador ou arquivo não salvo corretamente.

**Solução**:
```bash
# Limpar cache DNS e navegador
# Verificar se o arquivo foi salvo:
cat adguard/conf/AdGuardHome.yaml | grep -A2 "users:"

# Reiniciar completamente
docker compose restart adguardhome
```

### Container não inicia após mudar senha

**Causa**: Sintaxe YAML incorreta ou hash inválido.

**Solução**:
```bash
# Validar sintaxe YAML
docker run --rm -v $(pwd)/adguard/conf:/config alpine sh -c "apk add --no-cache yq && yq eval /config/AdGuardHome.yaml"

# Ver logs de erro
docker compose logs adguardhome

# Restaurar backup
cp adguard/conf/AdGuardHome.yaml.backup adguard/conf/AdGuardHome.yaml
docker compose restart adguardhome
```

### Traefik não aceita nova senha

**Causa**: Caracteres especiais não escapados ou formato incorreto.

**Solução**:
```bash
# Usar o comando correto com escape de $
echo $(htpasswd -nbB admin "sua_senha") | sed -e 's/\$/\$\$/g'

# Verificar se tem $$2y$$ (dois cifrões) no início
cat .env | grep TRAEFIK_PASSWORD
```

---

## 📚 Referências

- [AdGuard Home - Authentication](https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#authentication)
- [Traefik - BasicAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
- [CrowdSec - API Keys](https://docs.crowdsec.net/docs/user_guides/bouncers_configuration)
- [OWASP - Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
