#!/bin/bash
# Script para configurar e fazer push para GitHub usando chave SSH

set -e

REPO_URL="git@github.com-icu-sl4:danvoulez/icu-sl4.git"
SSH_KEY_NAME="id_ed25519_icu_sl4"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_CONFIG="$HOME/.ssh/config"

echo "=== ICU SL4 - Push para GitHub ==="
echo ""

# Verificar se a chave SSH existe
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "❌ Chave SSH não encontrada: $SSH_KEY_PATH"
    echo "Execute primeiro: ./scripts/setup_github_ssh.sh"
    exit 1
fi

# Configurar SSH config se necessário
if [ ! -f "$SSH_CONFIG" ] || ! grep -q "github.com-icu-sl4" "$SSH_CONFIG"; then
    echo "Configurando SSH config..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
    cat >> "$SSH_CONFIG" << EOF

# ICU SL4 GitHub
Host github.com-icu-sl4
  HostName github.com
  User git
  IdentityFile $SSH_KEY_PATH
  IdentitiesOnly yes
EOF
    echo "✓ SSH config atualizado"
fi

# Testar conexão SSH
echo "Testando conexão SSH com GitHub..."
if ssh -T git@github.com-icu-sl4 -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
    echo "✓ Conexão SSH OK"
else
    echo "⚠️  Aviso: Não foi possível verificar autenticação SSH"
    echo "   Certifique-se de que a chave foi adicionada ao GitHub"
fi

# Verificar se é um repositório git
if [ ! -d ".git" ]; then
    echo "Inicializando repositório git..."
    git init
    echo "✓ Repositório inicializado"
fi

# Configurar remote
echo "Configurando remote..."
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
echo "✓ Remote configurado: $REPO_URL"

# Verificar branch atual
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

# Se não tem branch, criar main
if [ -z "$CURRENT_BRANCH" ]; then
    git checkout -b main 2>/dev/null || git branch -M main
    CURRENT_BRANCH="main"
fi

# Adicionar arquivos
echo "Adicionando arquivos..."
git add .

# Verificar se há mudanças para commitar
if git diff --staged --quiet; then
    echo "⚠️  Nenhuma mudança para commitar"
else
    # Fazer commit
    echo "Fazendo commit..."
    git commit -m "Initial commit: ICU SL4 complete workspace

- Deterministic decision engine with cryptographic proof
- CLI tool for decisions and verification
- HTTP API with OpenAPI documentation
- FHIR integration endpoint
- PDF proof generation
- Helm chart for Kubernetes deployment
- Docker support
- NetworkPolicy/firewall configuration
- CI/CD ready" || echo "⚠️  Nenhuma mudança para commitar"
fi

# Push para GitHub
echo ""
echo "Fazendo push para GitHub..."
echo "Repositório: https://github.com/danvoulez/icu-sl4"
echo "Branch: $CURRENT_BRANCH"
echo ""

# Tentar push
if git push -u origin "$CURRENT_BRANCH" 2>&1; then
    echo ""
    echo "✅ Push realizado com sucesso!"
    echo ""
    echo "📦 Repositório: https://github.com/danvoulez/icu-sl4"
    echo "🔑 Usando chave SSH: $SSH_KEY_PATH"
else
    echo ""
    echo "❌ Erro ao fazer push"
    echo ""
    echo "Possíveis causas:"
    echo "1. Chave SSH não foi adicionada ao GitHub"
    echo "   → Acesse: https://github.com/settings/keys"
    echo "   → Adicione: $(cat ${SSH_KEY_PATH}.pub)"
    echo ""
    echo "2. Repositório não existe ou não tem permissão"
    echo "   → Verifique: https://github.com/danvoulez/icu-sl4"
    echo ""
    echo "3. Teste a conexão manualmente:"
    echo "   ssh -T git@github.com-icu-sl4"
    exit 1
fi

echo ""
echo "=== Concluído ==="

