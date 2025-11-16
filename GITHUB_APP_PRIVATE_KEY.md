# Configurar Chave Privada da GitHub App

## Status Atual

⚠️ **O arquivo anexado está vazio**. Você precisa obter a chave privada real da GitHub App.

## Como Obter a Chave Privada

### Opção 1: Baixar do GitHub (se ainda não baixou)

1. Acesse: **https://github.com/settings/apps**
2. Selecione a App: **ID 1460425**
3. Na seção **"Private keys"**, clique em **"Generate a private key"** (se ainda não tem)
4. Ou baixe a chave existente clicando no botão de download
5. Salve o arquivo `.pem`

### Opção 2: Se já tem a chave em outro local

Copie a chave para o projeto:

```bash
./scripts/setup_private_key.sh /caminho/para/sua-chave.pem
```

Ou manualmente:

```bash
cp /caminho/para/sua-chave.pem .github/github_app_private_key.pem
chmod 600 .github/github_app_private_key.pem
```

## Formato da Chave

A chave deve estar no formato PEM e começar com:

```
-----BEGIN RSA PRIVATE KEY-----
```

ou

```
-----BEGIN PRIVATE KEY-----
```

## Verificar Chave

```bash
# Verificar se a chave existe e não está vazia
ls -lh .github/github_app_private_key.pem
head -1 .github/github_app_private_key.pem

# Deve mostrar algo como:
# -----BEGIN RSA PRIVATE KEY-----
```

## Gerar Token

Depois de configurar a chave:

```bash
# 1. Instalar dependências (se ainda não instalou)
pip3 install PyJWT cryptography

# 2. Gerar token
./scripts/generate_github_app_token.sh

# 3. Usar o token
export GITHUB_TOKEN=$(./scripts/generate_github_app_token.sh | grep '^gho_' | head -1)
```

## Segurança

✅ A chave privada está protegida:
- No `.gitignore` (não será commitada)
- Permissões 600 (apenas você pode ler)
- Armazenada em `.github/` (fora do código)

⚠️ **NUNCA**:
- Commite a chave privada
- Compartilhe a chave
- Envie por email/chat não seguro

## Troubleshooting

### Erro: "Chave privada não encontrada"
- Verifique se o arquivo existe: `ls -la .github/github_app_private_key.pem`
- Verifique se as permissões estão corretas: `chmod 600 .github/github_app_private_key.pem`

### Erro: "Formato da chave incorreto"
- Verifique se começa com `-----BEGIN`
- Verifique se não está corrompido
- Tente baixar novamente do GitHub

### Erro ao gerar JWT
- Instale PyJWT: `pip3 install PyJWT cryptography`
- Verifique se a chave está completa (não vazia)
- Verifique se o App ID está correto (1460425)

