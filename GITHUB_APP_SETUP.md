# GitHub App Integration

Este repositório está configurado para usar GitHub App para autenticação e automação.

## Credenciais Configuradas

As credenciais da GitHub App estão em `.env.github_app` (não commitado):

- **App ID**: 1460425
- **Client ID**: Iv23lig0W6ehBkwA2PFi
- **Client Secret**: 9f96b45a2c55c9c492ac6c69cb0c2aa6f89140a6
- **Installation ID**: 72976874

## Uso

### Opção 1: Usar GitHub CLI (Recomendado)

```bash
# Já autenticado via GitHub CLI
./scripts/push_with_github_cli.sh
```

### Opção 2: Usar GitHub App

```bash
# Carregar credenciais
source .env.github_app

# Fazer push
./scripts/push_with_github_app.sh
```

### Opção 3: Usar Token Manual

```bash
# Gerar token em: https://github.com/settings/tokens
export GITHUB_TOKEN=seu_token_aqui
./scripts/push_with_token.sh
```

## GitHub App vs OAuth App

### OAuth App (Atual)
- Usa `client_id` e `client_secret`
- Mais simples de configurar
- Adequado para autenticação de usuário

### GitHub App (Completo)
- Requer private key JWT
- Mais seguro para automação
- Permissões granulares
- Melhor para CI/CD

## Para Configurar GitHub App Completo

1. **Baixar Private Key**:
   - Acesse: https://github.com/settings/apps
   - Selecione a App (ID: 1460425)
   - Baixe a private key (.pem)

2. **Gerar JWT Token**:
   ```bash
   # Usar biblioteca para gerar JWT com a private key
   # Exemplo com Node.js:
   npm install jsonwebtoken
   node scripts/generate_jwt.js
   ```

3. **Obter Installation Token**:
   ```bash
   # Usar JWT para obter installation token
   curl -X POST \
     -H "Authorization: Bearer $JWT_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     https://api.github.com/app/installations/$GITHUB_INSTALLATION_ID/access_tokens
   ```

## Scripts Disponíveis

- `push_with_github_cli.sh` - Usa GitHub CLI (mais fácil)
- `push_with_github_app.sh` - Usa GitHub App credentials
- `push_with_token.sh` - Usa token manual
- `push_to_github.sh` - Usa chave SSH
- `github_app_auth.sh` - Gera token de instalação

## Segurança

⚠️ **IMPORTANTE**:
- `.env.github_app` está no `.gitignore` - NÃO será commitado
- Nunca commite credenciais
- Use secrets do GitHub Actions para CI/CD
- Rotacione credenciais regularmente

## CI/CD Integration

Para usar no GitHub Actions, configure secrets:

```yaml
# .github/workflows/ci.yaml
env:
  GITHUB_APP_ID: ${{ secrets.GITHUB_APP_ID }}
  GITHUB_INSTALLATION_ID: ${{ secrets.GITHUB_INSTALLATION_ID }}
```

Adicione os secrets em: https://github.com/danvoulez/icu-sl4/settings/secrets/actions

