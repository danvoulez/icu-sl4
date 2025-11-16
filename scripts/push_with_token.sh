#!/bin/bash
# Script para fazer push usando token de acesso pessoal do GitHub

set -e

REPO_OWNER="danvoulez"
REPO_NAME="icu-sl4"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"

echo "=== ICU SL4 - Push com Token GitHub ==="
echo ""

# Verificar se é um repositório git
if [ ! -d ".git" ]; then
    echo "Inicializando repositório git..."
    git init
    echo "✓ Repositório inicializado"
fi

# Solicitar token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Token de acesso pessoal do GitHub necessário"
    echo ""
    echo "1. Crie um token em: https://github.com/settings/tokens"
    echo "2. Permissões necessárias:"
    echo "   - repo (Full control of private repositories)"
    echo ""
    read -sp "Cole o token aqui: " GITHUB_TOKEN
    echo ""
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Token não fornecido"
    exit 1
fi

# Configurar remote com token
echo "Configurando remote..."
REMOTE_URL_WITH_TOKEN="https://${GITHUB_TOKEN}@github.com/$REPO_OWNER/$REPO_NAME.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL_WITH_TOKEN" 2>/dev/null || git remote set-url origin "$REMOTE_URL_WITH_TOKEN"
echo "✓ Remote configurado"

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
if git diff --staged --quiet && [ -n "$(git log --oneline 2>/dev/null)" ]; then
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
echo "Repositório: https://github.com/$REPO_OWNER/$REPO_NAME"
echo "Branch: $CURRENT_BRANCH"
echo ""

if git push -u origin "$CURRENT_BRANCH" 2>&1; then
    echo ""
    echo "✅ Push realizado com sucesso!"
    echo ""
    echo "📦 Repositório: https://github.com/$REPO_OWNER/$REPO_NAME"
    echo "🔑 Autenticado via token"
else
    echo ""
    echo "❌ Erro ao fazer push"
    echo ""
    echo "Verifique:"
    echo "1. Token está válido e tem permissão 'repo'"
    echo "2. Repositório existe: https://github.com/$REPO_OWNER/$REPO_NAME"
    exit 1
fi

echo ""
echo "=== Concluído ==="

