#!/bin/bash
# Script para configurar SSH para GitHub

set -e

SSH_KEY_NAME="id_ed25519_icu_sl4"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_CONFIG="$HOME/.ssh/config"

echo "=== ICU SL4 - GitHub SSH Setup ==="
echo ""

# Verificar se a chave já existe
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✓ Chave SSH já existe: $SSH_KEY_PATH"
else
    echo "Gerando nova chave SSH..."
    ssh-keygen -t ed25519 -C "icu-sl4-github" -f "$SSH_KEY_PATH" -N ""
    chmod 600 "$SSH_KEY_PATH"
    echo "✓ Chave SSH gerada"
fi

echo ""
echo "=== CHAVE PÚBLICA ==="
echo ""
cat "${SSH_KEY_PATH}.pub"
echo ""
echo ""

# Configurar SSH config
if [ ! -f "$SSH_CONFIG" ]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
fi

if ! grep -q "github.com-icu-sl4" "$SSH_CONFIG"; then
    echo "Configurando ~/.ssh/config..."
    cat >> "$SSH_CONFIG" << EOF

# ICU SL4 GitHub
Host github.com-icu-sl4
  HostName github.com
  User git
  IdentityFile $SSH_KEY_PATH
  IdentitiesOnly yes
EOF
    echo "✓ SSH config atualizado"
else
    echo "✓ SSH config já contém configuração para github.com-icu-sl4"
fi

echo ""
echo "=== PRÓXIMOS PASSOS ==="
echo ""
echo "1. Copie a chave pública acima"
echo "2. Acesse: https://github.com/settings/keys"
echo "3. Clique em 'New SSH key'"
echo "4. Cole a chave e salve"
echo ""
echo "5. Configure o remote do repositório:"
echo "   git remote set-url origin git@github.com-icu-sl4:USERNAME/icu_sl4_complete.git"
echo ""
echo "6. Teste a conexão:"
echo "   ssh -T git@github.com-icu-sl4"
echo ""

