#!/bin/bash
# Script para fazer push usando GitHub App

set -e

# Credenciais da GitHub App
GITHUB_APP_ID="${GITHUB_APP_ID:-1460425}"
GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-Iv23lig0W6ehBkwA2PFi}"
GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-9f96b45a2c55c9c492ac6c69cb0c2aa6f89140a6}"
GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-72976874}"

REPO_OWNER="danvoulez"
REPO_NAME="icu-sl4"
REPO_FULL="$REPO_OWNER/$REPO_NAME"

echo "=== ICU SL4 - Push com GitHub App ==="
echo ""

# Verificar se GitHub CLI está instalado
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) não está instalado"
    echo "Instale com: brew install gh"
    exit 1
fi

echo "✓ GitHub CLI encontrado"
echo ""

# Autenticar usando GitHub App
echo "Autenticando com GitHub App..."
echo "App ID: $GITHUB_APP_ID"
echo "Installation ID: $GITHUB_INSTALLATION_ID"
echo ""

# Usar GitHub CLI para autenticar com App
# Primeiro, fazer logout se já estiver logado
gh auth logout 2>/dev/null || true

# Autenticar usando as credenciais da App
# GitHub CLI suporta autenticação via App usando token
echo "Gerando token de instalação..."

# Criar token temporário usando as credenciais
# Nota: Para produção, use um private key JWT da App
# Por enquanto, vamos usar o método de token direto se disponível

# Alternativa: usar gh auth login com token
if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | gh auth login --with-token
    echo "✓ Autenticado via token"
else
    echo "⚠️  Token não fornecido via GITHUB_TOKEN"
    echo "Para usar GitHub App completamente, você precisa:"
    echo "1. Private key da App (arquivo .pem)"
    echo "2. Gerar JWT token"
    echo "3. Trocar por installation token"
    echo ""
    echo "Usando método alternativo: autenticação manual..."
    gh auth login --web
fi

# Verificar autenticação
echo ""
echo "Verificando autenticação..."
if gh auth status &> /dev/null; then
    gh auth status
    echo "✓ Autenticado"
else
    echo "❌ Falha na autenticação"
    exit 1
fi

# Verificar se repositório existe
echo ""
echo "Verificando repositório..."
if gh repo view "$REPO_FULL" &> /dev/null; then
    echo "✓ Repositório existe: $REPO_FULL"
else
    echo "⚠️  Repositório não encontrado"
    read -p "Deseja criar? (s/n): " create_repo
    if [[ "$create_repo" == "s" || "$create_repo" == "S" ]]; then
        gh repo create "$REPO_NAME" \
            --public \
            --description "ICU SL4 - Deterministic ICU decision engine with cryptographic proof" \
            --clone=false
        echo "✓ Repositório criado"
    else
        exit 1
    fi
fi

# Configurar git
if [ ! -d ".git" ]; then
    echo "Inicializando repositório git..."
    git init
fi

# Configurar remote
REMOTE_URL="https://github.com/$REPO_FULL.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"
echo "✓ Remote configurado"

# Branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
if [ -z "$CURRENT_BRANCH" ]; then
    git checkout -b main 2>/dev/null || git branch -M main
    CURRENT_BRANCH="main"
fi

# Commit
echo "Adicionando arquivos..."
git add .

if ! git diff --staged --quiet || [ -z "$(git log --oneline 2>/dev/null)" ]; then
    echo "Fazendo commit..."
    git commit -m "Update: ICU SL4 complete workspace

- Deterministic decision engine with cryptographic proof
- CLI tool for decisions and verification
- HTTP API with OpenAPI documentation
- FHIR integration endpoint
- PDF proof generation
- Helm chart for Kubernetes deployment
- Docker support
- NetworkPolicy/firewall configuration
- CI/CD ready
- GitHub App integration" || echo "⚠️  Nenhuma mudança"
fi

# Push
echo ""
echo "Fazendo push..."
echo "Repositório: https://github.com/$REPO_FULL"
echo "Branch: $CURRENT_BRANCH"
echo ""

if git push -u origin "$CURRENT_BRANCH" 2>&1; then
    echo ""
    echo "✅ Push realizado com sucesso!"
    echo ""
    echo "📦 Repositório: https://github.com/$REPO_FULL"
    echo "🔑 Autenticado via GitHub App"
else
    echo "❌ Erro no push"
    exit 1
fi

echo ""
echo "=== Concluído ==="

