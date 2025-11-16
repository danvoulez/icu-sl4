#!/bin/bash
# Script para fazer push usando GitHub CLI (gh) - funciona com GitHub App ou token

set -e

REPO_OWNER="danvoulez"
REPO_NAME="icu-sl4"
REPO_FULL="$REPO_OWNER/$REPO_NAME"

echo "=== ICU SL4 - Push com GitHub CLI ==="
echo ""

# Verificar se GitHub CLI está instalado
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) não está instalado"
    echo ""
    echo "Instale com:"
    echo "  macOS: brew install gh"
    echo "  Linux: sudo apt install gh  # ou use o gerenciador de pacotes da sua distro"
    echo ""
    exit 1
fi

echo "✓ GitHub CLI encontrado: $(gh --version | head -1)"
echo ""

# Verificar autenticação
echo "Verificando autenticação..."
if gh auth status &> /dev/null; then
    echo "✓ Autenticado no GitHub"
    gh auth status
else
    echo "⚠️  Não autenticado no GitHub"
    echo ""
    echo "Autenticando..."
    echo "Escolha o método:"
    echo "1. GitHub.com (web browser)"
    echo "2. GitHub Enterprise Server"
    echo "3. Token de acesso pessoal"
    echo ""
    read -p "Escolha (1-3): " auth_method
    
    case $auth_method in
        1)
            gh auth login --web
            ;;
        2)
            read -p "GitHub Enterprise URL: " enterprise_url
            gh auth login --hostname "$enterprise_url"
            ;;
        3)
            read -p "Token de acesso pessoal: " token
            echo "$token" | gh auth login --with-token
            ;;
        *)
            echo "Opção inválida"
            exit 1
            ;;
    esac
fi

echo ""
echo "Verificando se repositório existe..."
if gh repo view "$REPO_FULL" &> /dev/null; then
    echo "✓ Repositório existe: $REPO_FULL"
else
    echo "⚠️  Repositório não encontrado ou sem acesso"
    echo ""
    read -p "Deseja criar o repositório? (s/n): " create_repo
    if [[ "$create_repo" == "s" || "$create_repo" == "S" ]]; then
        echo "Criando repositório..."
        gh repo create "$REPO_NAME" \
            --public \
            --description "ICU SL4 - Deterministic ICU decision engine with cryptographic proof" \
            --clone=false
        echo "✓ Repositório criado"
    else
        echo "❌ Repositório não existe. Crie manualmente em: https://github.com/new"
        exit 1
    fi
fi

# Verificar se é um repositório git
if [ ! -d ".git" ]; then
    echo "Inicializando repositório git..."
    git init
    echo "✓ Repositório inicializado"
fi

# Configurar remote usando GitHub CLI (usa HTTPS com token automaticamente)
echo "Configurando remote..."
REMOTE_URL="https://github.com/$REPO_FULL.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"
echo "✓ Remote configurado: $REMOTE_URL"

# Verificar branch atual
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

# Se não tem branch, criar main
if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" == "" ]; then
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

# Push para GitHub usando GitHub CLI (automaticamente autentica)
echo ""
echo "Fazendo push para GitHub..."
echo "Repositório: https://github.com/$REPO_FULL"
echo "Branch: $CURRENT_BRANCH"
echo ""

# Usar git push com credenciais do GitHub CLI
if git push -u origin "$CURRENT_BRANCH" 2>&1; then
    echo ""
    echo "✅ Push realizado com sucesso!"
    echo ""
    echo "📦 Repositório: https://github.com/$REPO_FULL"
    echo "🔑 Autenticado via GitHub CLI"
else
    echo ""
    echo "❌ Erro ao fazer push"
    echo ""
    echo "Tentando com GitHub CLI diretamente..."
    if gh repo sync "$REPO_FULL" --force 2>&1; then
        echo "✅ Sincronizado via GitHub CLI"
    else
        echo "❌ Falha na sincronização"
        echo ""
        echo "Tente manualmente:"
        echo "  git push -u origin $CURRENT_BRANCH"
        exit 1
    fi
fi

echo ""
echo "=== Concluído ==="
echo ""
echo "🌐 Acesse: https://github.com/$REPO_FULL"

