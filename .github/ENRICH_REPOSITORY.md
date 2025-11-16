# Enriquecer Repositório

Instruções para enriquecer o repositório com metadados de forma discreta mas incisiva.

## Descrição Recomendada

```
Sistema de decisão determinística para UTI com garantia matemática de consistência e rastreabilidade
```

## Topics Recomendados

- `healthcare` - Saúde
- `icu` - Unidade de Terapia Intensiva  
- `decision-support` - Sistema de apoio à decisão
- `deterministic` - Decisões determinísticas
- `rust` - Linguagem de programação
- `fhir` - Padrão FHIR para dados de saúde
- `slsa` - Supply-chain Levels for Software Artifacts
- `cryptography` - Criptografia e assinaturas digitais

## Como Aplicar

### Via Interface Web

1. Acesse: https://github.com/danvoulez/icu-sl4/settings
2. **Descrição**: Edite o campo "Description" na seção "About"
3. **Topics**: Clique em "Add topics" e adicione os topics listados acima

### Via GitHub CLI

```bash
# Com GitHub CLI autenticado
gh repo edit danvoulez/icu-sl4 \
  --description "Sistema de decisão determinística para UTI com garantia matemática de consistência e rastreabilidade" \
  --add-topic healthcare \
  --add-topic icu \
  --add-topic decision-support \
  --add-topic deterministic \
  --add-topic rust \
  --add-topic fhir \
  --add-topic slsa \
  --add-topic cryptography
```

### Via API (com token)

```bash
# Gerar token
TOKEN=$(./scripts/generate_github_app_token.sh | grep "Installation token:" | awk '{print $3}')

# Atualizar descrição
curl -X PATCH \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/danvoulez/icu-sl4 \
  -d '{"description":"Sistema de decisão determinística para UTI com garantia matemática de consistência e rastreabilidade"}'

# Adicionar topics
curl -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.mercy-preview+json" \
  https://api.github.com/repos/danvoulez/icu-sl4/topics \
  -d '{"names":["healthcare","icu","decision-support","deterministic","rust","fhir","slsa","cryptography"]}'
```

## Objetivo

Facilitar a descoberta do repositório por:
- Profissionais de saúde interessados em sistemas de apoio à decisão
- Desenvolvedores trabalhando com healthcare
- Pesquisadores em sistemas determinísticos
- Profissionais de segurança de software (SLSA)

## Tom

Discreto mas incisivo:
- Descrição clara e objetiva
- Topics relevantes e específicos
- Comunicação profissional
- Sem exageros

