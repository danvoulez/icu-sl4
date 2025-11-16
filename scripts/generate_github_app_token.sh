#!/bin/bash
# Script para gerar token de instalação da GitHub App usando JWT

set -e

GITHUB_APP_ID="${GITHUB_APP_ID:-1460425}"
GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-72976874}"
PRIVATE_KEY_FILE="${GITHUB_APP_PRIVATE_KEY:-.github/github_app_private_key.pem}"

echo "=== Gerar Token GitHub App ==="
echo ""

# Verificar se a chave privada existe
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    echo "❌ Chave privada não encontrada: $PRIVATE_KEY_FILE"
    echo ""
    echo "Configure:"
    echo "  export GITHUB_APP_PRIVATE_KEY=/caminho/para/private-key.pem"
    exit 1
fi

echo "✓ Chave privada encontrada: $PRIVATE_KEY_FILE"
echo "App ID: $GITHUB_APP_ID"
echo "Installation ID: $GITHUB_INSTALLATION_ID"
echo ""

# Verificar se Python está disponível (para gerar JWT)
if command -v python3 &> /dev/null; then
    echo "Gerando JWT token com Python..."
    
    # Criar script Python temporário para gerar JWT
    cat > /tmp/generate_jwt.py << 'PYTHON_SCRIPT'
import sys
import time
import jwt
import json

if len(sys.argv) < 3:
    print("Uso: python3 generate_jwt.py <app_id> <private_key_file>")
    sys.exit(1)

app_id = sys.argv[1]
private_key_file = sys.argv[2]

# Ler chave privada
with open(private_key_file, 'r') as f:
    private_key = f.read()

# Gerar JWT
now = int(time.time())
payload = {
    'iat': now - 60,  # 60 segundos atrás para evitar problemas de clock skew
    'exp': now + (10 * 60),  # Expira em 10 minutos
    'iss': app_id
}

token = jwt.encode(payload, private_key, algorithm='RS256')
print(token)
PYTHON_SCRIPT

    # Gerar JWT
    JWT_TOKEN=$(python3 /tmp/generate_jwt.py "$GITHUB_APP_ID" "$PRIVATE_KEY_FILE" 2>&1)
    
    if [ -z "$JWT_TOKEN" ] || echo "$JWT_TOKEN" | grep -q "Error\|Traceback\|Exception"; then
        echo "❌ Erro ao gerar JWT"
        echo "Erro: $JWT_TOKEN"
        echo ""
        echo "Verifique:"
        echo "  1. Chave privada está no formato PEM correto"
        echo "  2. PyJWT está instalado: pip3 install PyJWT cryptography"
        rm -f /tmp/generate_jwt.py
        exit 1
    fi
    
    echo "✓ JWT token gerado"
    echo ""
    
    # Obter installation token
    echo "Obtendo installation token..."
    TOKEN_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/app/installations/$GITHUB_INSTALLATION_ID/access_tokens")
    
    INSTALLATION_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null)
    
    if [ -n "$INSTALLATION_TOKEN" ] && [ "$INSTALLATION_TOKEN" != "None" ]; then
        echo "✅ Token de instalação gerado com sucesso!"
        echo ""
        echo "Token (válido por 1 hora):"
        echo "$INSTALLATION_TOKEN"
        echo ""
        echo "Para usar:"
        echo "export GITHUB_TOKEN=\"$INSTALLATION_TOKEN\""
        echo ""
        echo "Ou adicione ao .env:"
        echo "echo 'GITHUB_TOKEN=$INSTALLATION_TOKEN' >> .env.github_app"
    else
        echo "❌ Erro ao obter installation token"
        echo "Resposta: $TOKEN_RESPONSE"
        exit 1
    fi
    
    # Limpar
    rm -f /tmp/generate_jwt.py
    
elif command -v node &> /dev/null; then
    echo "Gerando JWT token com Node.js..."
    echo "⚠️  Implementação Node.js requer jsonwebtoken package"
    echo "Instale: npm install jsonwebtoken"
    exit 1
else
    echo "❌ Python3 ou Node.js necessário para gerar JWT"
    echo ""
    echo "Instale Python:"
    echo "  macOS: brew install python3"
    echo "  Linux: sudo apt install python3"
    echo ""
    echo "Depois instale PyJWT:"
    echo "  pip3 install PyJWT cryptography"
    exit 1
fi

