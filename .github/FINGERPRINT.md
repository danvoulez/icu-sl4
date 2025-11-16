# Fingerprints de Chaves

## Fingerprint Fornecido

```
SHA256:F0kpEkWmZkEzu0aTNWoiVMMgr06jc6GW9x3NafD/UCg=
```

## Chaves Configuradas

### 1. Chave SSH Ed25519 (ICU SL4)

**Localização**: `~/.ssh/id_ed25519_icu_sl4`

Para verificar fingerprint:
```bash
ssh-keygen -lf ~/.ssh/id_ed25519_icu_sl4.pub
```

**Uso**: Autenticação SSH para GitHub

### 2. Chave Privada GitHub App

**Localização**: `.github/github_app_private_key.pem`

Para verificar fingerprint (se for RSA):
```bash
openssl rsa -in .github/github_app_private_key.pem -pubout | ssh-keygen -lf -
```

**Uso**: Autenticação GitHub App via JWT

## Verificação

Para verificar se o fingerprint corresponde a alguma chave:

```bash
# Verificar chave SSH
ssh-keygen -lf ~/.ssh/id_ed25519_icu_sl4.pub

# Verificar chave GitHub App (se RSA)
openssl rsa -in .github/github_app_private_key.pem -pubout | ssh-keygen -lf -
```

## GitHub App Fingerprint

O fingerprint da GitHub App geralmente pode ser encontrado em:
- https://github.com/settings/apps
- Selecione a App (ID: 1460425)
- Veja a seção "Public key" ou "Fingerprint"

## Segurança

⚠️ **IMPORTANTE**: 
- Fingerprints são públicos e podem ser compartilhados
- Eles são usados para verificar a identidade de chaves
- Não revelam a chave privada

