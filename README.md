# ICU SL4 — Sistema de Decisão Determinística para UTI

Sistema que ajuda médicos a tomar decisões baseadas em protocolos, com garantia matemática de que a mesma situação sempre produz a mesma recomendação.

## O Problema que Resolve

Em UTI, decisões precisam ser:
- **Consistentes**: mesma situação = mesma decisão
- **Rastreáveis**: saber exatamente por que uma decisão foi tomada
- **Verificáveis**: poder confirmar depois que a decisão estava correta

Este sistema garante essas três coisas usando matemática (criptografia).

## Como Funciona

1. **Entrada**: Dados do paciente (ex: saturação de oxigênio, frequência cardíaca)
2. **Processamento**: Aplica protocolos médicos (ex: "se SpO2 < 90%, aumentar O2")
3. **Saída**: Lista de ações recomendadas com prazos
4. **Prova**: Cada decisão vem com uma "assinatura digital" que prova que foi gerada corretamente

A assinatura permite verificar depois, sem precisar do servidor original, que a decisão não foi alterada.

## Por Que Isso Importa

### Para Médicos
- Decisões consistentes, mesmo com diferentes operadores
- Rastreabilidade completa para auditoria
- Verificação independente da decisão

### Para Hospitais
- Compliance com regulamentações
- Auditoria automatizada
- Redução de erros por inconsistência

### Para Pacientes
- Mesma qualidade de decisão, independente de quem opera
- Transparência e rastreabilidade
- Maior confiança no processo

## Componentes

### 1. Engine (Motor de Decisão)
O coração do sistema. Processa dados do paciente e protocolos, gerando decisões determinísticas.

### 2. CLI (Linha de Comando)
Ferramenta para usar o sistema via terminal. Útil para testes e automação.

### 3. HTTP Server (Servidor Web)
API REST que permite integração com outros sistemas hospitalares.

### 4. Integração FHIR
Aceita dados no formato FHIR (padrão internacional para dados de saúde).

### 5. Documentação OpenAPI
Interface Swagger para explorar e testar a API.

## Exemplo de Uso

```bash
# Decisão via CLI
./target/release/icu_sl4_cli decide \
  --input examples/input.json \
  --policy examples/policy_hypoxemia.yaml \
  --keypair examples/keypair.json \
  --out /tmp/decision.json

# Verificar a decisão depois
./target/release/icu_sl4_cli verify --decision /tmp/decision.json
# ✓ Signature valid
```

## O Que Torna Isso Diferente

### Determinismo
A mesma entrada sempre produz a mesma saída. Isso é garantido matematicamente, não por "esperança".

### Verificação Offline
Você pode verificar uma decisão mesmo sem acesso ao servidor original. A assinatura digital prova a integridade.

### Rastreabilidade Completa
Cada decisão inclui:
- Quando foi gerada
- Que protocolos foram usados
- Que dados do paciente foram considerados
- Assinatura criptográfica que prova autenticidade

### Padrões de Indústria
Usa padrões reconhecidos:
- **FHIR R4** para dados de saúde
- **OpenAPI** para documentação de API
- **SLSA Provenance** para rastreabilidade de build
- **Ed25519** para assinaturas digitais
- **BLAKE3** para hashing

## Instalação e Uso

### Build
```bash
cargo build --release
```

### Servidor HTTP
```bash
cargo run -p icu_sl4_http --release
```

Acesse:
- **Swagger UI**: http://localhost:8787/swagger-ui/
- **Health check**: http://localhost:8787/healthz

### Docker
```bash
docker build -f docker/Dockerfile.http -t icu-sl4-http:local .
docker run --rm -p 8787:8787 icu-sl4-http:local
```

### Kubernetes
```bash
# Deploy direto
kubectl apply -f k8s/deployment.yaml

# Ou via Helm
helm install icu-sl4-http ./helm/icu-sl4-http
```

## Estrutura do Projeto

```
icu_sl4_complete/
├── crates/
│   ├── icu_sl4_engine/    # Motor de decisão
│   ├── icu_sl4_cli/       # Interface linha de comando
│   ├── icu_sl4_http/      # Servidor HTTP/API
│   └── icu_sl4_pdf/       # Geração de PDF (opcional)
├── examples/              # Exemplos de uso
├── helm/                  # Helm chart para Kubernetes
├── k8s/                   # Manifests Kubernetes
├── docker/                # Dockerfiles
└── scripts/               # Scripts auxiliares
```

## Segurança e Compliance

### Assinaturas Digitais
Cada decisão é assinada com Ed25519, permitindo verificação independente.

### Provenance (Rastreabilidade de Build)
O sistema gera "provenance" (prova de origem) para os binários, seguindo o padrão SLSA. Isso permite verificar:
- De onde veio o código (git commit)
- Como foi compilado (versão do Rust, dependências)
- Quando foi buildado
- Integridade do binário (hash criptográfico)

### Network Policies
Inclui configuração de firewall (NetworkPolicy) para Kubernetes, controlando quais serviços podem se comunicar.

## Documentação Adicional

- **SLSA Provenance**: `SLSA_PROVENANCE.md` - Explica o sistema de rastreabilidade
- **Helm Chart**: `helm/icu-sl4-http/README.md` - Guia de deploy no Kubernetes
- **Firewall**: `helm/icu-sl4-http/FIREWALL.md` - Configuração de segurança

## Licença

Apache-2.0

## Contribuindo

Issues e pull requests são bem-vindos. Por favor, mantenha o código formatado (`cargo fmt`) e sem warnings do clippy (`cargo clippy`).

## CI/CD

O projeto inclui:
- **CI**: Verificação automática de formatação, clippy, build e testes
- **Release**: Geração automática de binários, SBOM (SPDX) e provenance em releases

---

**Nota**: Este é um sistema de apoio à decisão. Decisões médicas finais sempre devem ser tomadas por profissionais qualificados.
