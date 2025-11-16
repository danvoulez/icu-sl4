# SLSA Provenance - Melhores Práticas

## O que vai para o GitHub? ✅

### ✅ SIM - Vai para o Repositório

1. **Scripts de geração/verificação**
   - `scripts/generate_slsa_provenance.sh`
   - `scripts/verify_slsa_provenance.sh`
   - ✅ Essenciais para outros desenvolvedores

2. **Documentação**
   - `SLSA_PROVENANCE.md`
   - `SLSA_BEST_PRACTICES.md` (este arquivo)
   - ✅ Ajuda outros a entender e usar

3. **GitHub Actions Workflow**
   - `.github/workflows/release.yaml` (já tem `actions/attest-build-provenance@v1`)
   - ✅ Gera provenance automaticamente no CI

### ❌ NÃO - NÃO vai para o Repositório

1. **Provenance gerada localmente**
   - `target/release/*.provenance.json`
   - `target/release/*.provenance.json.sig`
   - ❌ Artefatos de build (já estão em `target/` no `.gitignore`)

2. **Binários**
   - `target/release/icu_sl4_cli`
   - ❌ Já ignorados pelo `.gitignore`

## Estratégia Recomendada

### 1. Local (Desenvolvimento)
```bash
# Gerar provenance localmente para testes
./scripts/generate_slsa_provenance.sh target/release/icu_sl4_cli
# ✅ Arquivo fica em target/ (já ignorado pelo git)
```

### 2. CI/CD (GitHub Actions)
O workflow `release.yaml` já está configurado:
```yaml
- name: Generate provenance
  uses: actions/attest-build-provenance@v1
  with:
    subject-path: |
      target/release/icu_sl4_cli
      target/release/icu_sl4_http
      target/release/icu_sl4_pdf
```

**O que acontece:**
- ✅ Provenance é gerada automaticamente no CI
- ✅ Attestation é criada no GitHub (não vai para o repo)
- ✅ Disponível via GitHub API de Attestations
- ✅ Aparece na aba "Attestations" do release

### 3. Release Assets (Opcional)
Se quiser incluir provenance como asset do release:
```yaml
- name: Generate SLSA Provenance (custom)
  run: |
    ./scripts/generate_slsa_provenance.sh \
      target/release/icu_sl4_cli \
      provenance/icu_sl4_cli.provenance.json \
      ${{ secrets.SIGNING_KEY_HEX }}

- name: Create Release
  uses: softprops/action-gh-release@v2
  with:
    files: |
      target/release/icu_sl4_cli
      provenance/icu_sl4_cli.provenance.json  # ✅ Incluir como asset
      sbom.spdx.json
```

## Atualizar .gitignore

O `.gitignore` já está correto:
```
target/          # ✅ Já ignora tudo em target/, incluindo provenance
```

**Não precisa adicionar nada!** A provenance local fica em `target/` e já está ignorada.

## Verificar o que vai para o GitHub

```bash
# Ver o que será commitado
git status

# Verificar se provenance está ignorada
git check-ignore -v target/release/*.provenance.json
# Deve retornar: target/release/*.provenance.json:1:target/
```

## Resumo

| Item | Vai para GitHub? | Onde? |
|------|------------------|-------|
| Scripts | ✅ SIM | `scripts/` |
| Documentação | ✅ SIM | Raiz do repo |
| Provenance local | ❌ NÃO | `target/` (ignorado) |
| Provenance CI | ✅ SIM | GitHub Attestations API |
| Release assets | ⚠️ OPCIONAL | Release assets (se configurado) |

## Próximos Passos

1. ✅ Scripts já criados
2. ✅ Documentação criada
3. ✅ `.gitignore` já está correto
4. ✅ GitHub Actions já gera provenance
5. ⚠️ **Fazer commit dos scripts e documentação:**
   ```bash
   git add scripts/generate_slsa_provenance.sh
   git add scripts/verify_slsa_provenance.sh
   git add SLSA_PROVENANCE.md
   git add SLSA_BEST_PRACTICES.md
   git commit -m "Add SLSA Provenance scripts and documentation"
   git push
   ```

## Referências

- [SLSA Framework](https://slsa.dev/)
- [GitHub Attestations](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-for-github-actions#using-attestations)
- [actions/attest-build-provenance](https://github.com/actions/attest-build-provenance)

