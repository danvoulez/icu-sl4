#!/bin/bash
# Script helper para configurar a chave privada da GitHub App

set -e

PRIVATE_KEY_SOURCE="${1:-agent-minicontratos-vv.2025-05-16.private-key.pem}"
PRIVATE_KEY_DEST=".github/github_app_private_key.pem"

echo "=== Configurar Chave Privada GitHub App ==="
echo ""

# Verificar se o arquivo fonte existe
if [ ! -f "$PRIVATE_KEY_SOURCE" ]; then
    echo "❌ Arquivo não encontrado: $PRIVATE_KEY_SOURCE"
    echo ""
    echo "Uso:"
    echo "  ./scripts/setup_private_key.sh /caminho/para/private-key.pem"
    echo ""
    echo "Ou se o arquivo está no diretório atual:"
    echo "  ./scripts/setup_private_key.sh agent-minicontratos-vv.2025-05-16.private-key.pem"
    exit 1
fi

# Criar diretório .github se não existir
mkdir -p .github

# Copiar chave
echo "Copiando chave privada..."
cp "$PRIVATE_KEY_SOURCE" "$PRIVATE_KEY_DEST"

# Proteger permissões
chmod 600 "$PRIVATE_KEY_DEST"

echo "✓ Chave copiada para: $PRIVATE_KEY_DEST"
echo "✓ Permissões configuradas (600)"

# Verificar se é uma chave PEM válida
if head -1 "$PRIVATE_KEY_DEST" | grep -q "BEGIN.*PRIVATE KEY"; then
    echo "✓ Chave PEM válida"
else
    echo "⚠️  Aviso: Formato da chave pode estar incorreto"
fi

echo ""
echo "✅ Chave privada configurada!"
echo ""
echo "Próximos passos:"
echo "1. Instale PyJWT: pip3 install PyJWT cryptography"
echo "2. Gere token: ./scripts/generate_github_app_token.sh"
echo "3. Use no push: export GITHUB_TOKEN=\$(./scripts/generate_github_app_token.sh)"

