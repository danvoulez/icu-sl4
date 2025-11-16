# SLSA Provenance Attestation

## O que é SLSA Provenance?

**SLSA (Supply-chain Levels for Software Artifacts)** é um padrão de indústria para provar a proveniência e integridade de artefatos de software. É **mais importante que PDF** porque:

1. **Padrão de Indústria**: Usado por Google, GitHub, CNCF, e outros
2. **Verificável**: Ferramentas padrão podem verificar automaticamente
3. **Completo**: Inclui metadados de build, dependências, fonte, etc.
4. **Supply Chain Security**: Essencial para segurança da cadeia de suprimentos
5. **Machine-Readable**: Pode ser processado por ferramentas de compliance

## Comparação: PDF vs SLSA Provenance

| Aspecto | PDF | SLSA Provenance |
|---------|-----|-----------------|
| Padrão | Proprietário | Padrão de indústria (in-toto/SLSA) |
| Verificação | Manual | Automática (ferramentas padrão) |
| Metadados | Limitados | Completos (build, deps, source, etc.) |
| Integração | Nenhuma | CI/CD, registries, scanners |
| Supply Chain | Não | Sim (essencial) |
| Compliance | Manual | Automatizado |

## Gerar Provenance

```bash
# Gerar attestation SLSA para o binário
./scripts/generate_slsa_provenance.sh \
  target/release/icu_sl4_cli \
  target/release/icu_sl4_cli.provenance.json \
  000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

Isso gera:
- `*.provenance.json` - Attestation SLSA (in-toto format)
- `*.provenance.json.sig` - Assinatura Ed25519

## Verificar Provenance

```bash
# Verificar integridade e assinatura
./scripts/verify_slsa_provenance.sh \
  target/release/icu_sl4_cli.provenance.json \
  target/release/icu_sl4_cli.provenance.json.sig \
  target/release/icu_sl4_cli
```

## O que a Provenance Prova?

A attestation SLSA prova:

1. **O que foi construído**
   - Hash do binário (BLAKE3 + SHA256)
   - Tamanho do arquivo

2. **Como foi construído**
   - Versão do Rust/Cargo
   - Perfil de build (release)
   - Target architecture

3. **De onde veio**
   - Repositório Git
   - Commit hash
   - Branch

4. **Quando foi construído**
   - Timestamp UTC

5. **Dependências**
   - Hash do Cargo.lock
   - Versões das dependências

6. **Integridade**
   - Assinatura Ed25519
   - Hash canônico do JSON

## Estrutura da Attestation

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    {
      "name": "icu_sl4_cli",
      "digest": {
        "blake3": "...",
        "sha256": "..."
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://slsa.dev/buildDefinition/v1?buildType=cargo",
      "externalParameters": {
        "cargo": { ... },
        "source": { ... }
      },
      "resolvedDependencies": [ ... ]
    },
    "runDetails": {
      "builder": { ... },
      "metadata": { ... }
    }
  }
}
```

## Integração com CI/CD

### GitHub Actions

```yaml
- name: Generate SLSA Provenance
  run: |
    ./scripts/generate_slsa_provenance.sh \
      target/release/icu_sl4_cli \
      target/release/icu_sl4_cli.provenance.json \
      ${{ secrets.SIGNING_KEY_HEX }}
    
- name: Upload Provenance
  uses: actions/upload-artifact@v4
  with:
    name: provenance
    path: target/release/*.provenance.json*
```

### Verificação Automática

```yaml
- name: Verify Provenance
  run: |
    ./scripts/verify_slsa_provenance.sh \
      target/release/icu_sl4_cli.provenance.json \
      target/release/icu_sl4_cli.provenance.json.sig \
      target/release/icu_sl4_cli
```

## Por que é Mais Importante que PDF?

1. **Padrão de Indústria**: SLSA é usado por Google, GitHub, CNCF
2. **Automação**: Ferramentas podem verificar automaticamente
3. **Supply Chain Security**: Essencial para segurança da cadeia de suprimentos
4. **Compliance**: Atende requisitos de compliance (SLSA Level 1+)
5. **Integração**: Funciona com registries, scanners, CI/CD
6. **Machine-Readable**: Pode ser processado por ferramentas

## Referências

- [SLSA Specification](https://slsa.dev/spec/v1.0/)
- [in-toto Attestation](https://github.com/in-toto/attestation)
- [SLSA Levels](https://slsa.dev/spec/v1.0/levels)

