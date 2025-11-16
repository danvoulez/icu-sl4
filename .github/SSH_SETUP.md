# Configuração SSH para GitHub

## Chave SSH Gerada

Uma chave SSH Ed25519 foi gerada para este repositório:
- **Chave privada**: `~/.ssh/id_ed25519_icu_sl4` (NUNCA compartilhe!)
- **Chave pública**: `~/.ssh/id_ed25519_icu_sl4.pub` (adicione ao GitHub)

## Como Adicionar ao GitHub

1. **Copie a chave pública:**
   ```bash
   cat ~/.ssh/id_ed25519_icu_sl4.pub
   ```

2. **Acesse GitHub Settings:**
   - Vá para: https://github.com/settings/keys
   - Clique em "New SSH key"

3. **Adicione a chave:**
   - **Title**: `ICU SL4 Repository` (ou outro nome descritivo)
   - **Key**: Cole o conteúdo da chave pública
   - Clique em "Add SSH key"

## Configuração do SSH Client

Adicione ao arquivo `~/.ssh/config`:

```
Host github.com-icu-sl4
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_icu_sl4
  IdentitiesOnly yes
```

## Configurar o Repositório

Depois de adicionar a chave ao GitHub, configure o remote:

```bash
# Se ainda não tem remote configurado
git remote add origin git@github.com-icu-sl4:USERNAME/icu_sl4_complete.git

# Ou se já tem, atualize:
git remote set-url origin git@github.com-icu-sl4:USERNAME/icu_sl4_complete.git
```

## Testar Conexão

```bash
ssh -T git@github.com-icu-sl4
```

Você deve ver uma mensagem como:
```
Hi USERNAME! You've successfully authenticated...
```

## Segurança

⚠️ **IMPORTANTE:**
- **NUNCA** compartilhe a chave privada (`id_ed25519_icu_sl4`)
- Mantenha a chave privada com permissões restritas: `chmod 600 ~/.ssh/id_ed25519_icu_sl4`
- A chave pública pode ser compartilhada livremente

## Backup

Se precisar fazer backup das chaves:
```bash
# Backup seguro (criptografado)
tar -czf ssh_keys_backup.tar.gz ~/.ssh/id_ed25519_icu_sl4*
# Guarde em local seguro e criptografado
```

## Rotação de Chaves

Para rotacionar a chave no futuro:
1. Gere nova chave: `ssh-keygen -t ed25519 -C "new-key" -f ~/.ssh/id_ed25519_icu_sl4_new`
2. Adicione ao GitHub
3. Teste a conexão
4. Remova a chave antiga do GitHub
5. Renomeie a nova chave para substituir a antiga

