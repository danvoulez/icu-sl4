#!/bin/bash
# Script para autenticar usando GitHub App e gerar token de instalação

set -e

GITHUB_APP_ID="${GITHUB_APP_ID:-1460425}"
GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-Iv23lig0W6ehBkwA2PFi}"
GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-9f96b45a2c55c9c492ac6c69cb0c2aa6f89140a6}"
GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-72976874}"

echo "=== GitHub App Authentication ==="
echo ""

# Verificar se jq está instalado (para parse JSON)
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq não instalado - instalando..."
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo "Instale jq manualmente: https://stedolan.github.io/jq/"
        exit 1
    fi
fi

echo "App ID: $GITHUB_APP_ID"
echo "Installation ID: $GITHUB_INSTALLATION_ID"
echo ""

# Gerar token de instalação usando OAuth App credentials
# Nota: Para GitHub App completo, precisa de private key JWT
# Aqui usamos OAuth App credentials como alternativa

echo "Gerando token de acesso..."

# Usar OAuth App para obter token
TOKEN_RESPONSE=$(curl -s -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"client_id\":\"$GITHUB_CLIENT_ID\",\"client_secret\":\"$GITHUB_CLIENT_SECRET\"}" \
    "https://api.github.com/app/installations/$GITHUB_INSTALLATION_ID/access_tokens" \
    -u "$GITHUB_CLIENT_ID:$GITHUB_CLIENT_SECRET" 2>&1)

if echo "$TOKEN_RESPONSE" | jq -e '.token' > /dev/null 2>&1; then
    INSTALLATION_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')
    echo "✓ Token gerado com sucesso"
    echo ""
    echo "Token (use para autenticação):"
    echo "$INSTALLATION_TOKEN"
    echo ""
    echo "Para usar com git:"
    echo "export GITHUB_TOKEN=\"$INSTALLATION_TOKEN\""
    echo "git config --global credential.helper store"
    echo "echo \"https://\$GITHUB_TOKEN@github.com\" > ~/.git-credentials"
else
    echo "⚠️  Não foi possível gerar token via API direta"
    echo ""
    echo "Usando GitHub CLI para autenticação..."
    echo ""
    echo "Opções:"
    echo "1. Usar GitHub CLI: gh auth login"
    echo "2. Usar token manual: export GITHUB_TOKEN=seu_token"
    echo ""
    echo "Para GitHub App completo, você precisa:"
    echo "- Private key da App (.pem file)"
    echo "- Gerar JWT token"
    echo "- Trocar por installation token"
fi

