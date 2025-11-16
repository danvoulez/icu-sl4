# Plano para Fazer o CI Passar ✅

## Problemas Identificados

1. ❌ `genpdf::fonts::dejavu_sans()` não existe
2. ❌ `genpdf::fonts::FontFamily::default()` não existe  
3. ❌ `Style::set_align()` não existe
4. ❌ Alguns `format!` ainda precisam inline args
5. ❌ CI falhando em múltiplos pontos

## Plano de Ação

### Fase 1: Corrigir genpdf (PDF crate)
- [ ] Verificar API correta do genpdf 0.2
- [ ] Usar `genpdf::fonts::builtin::Helvetica` ou similar
- [ ] Remover `set_align` (não existe)
- [ ] Simplificar estilo do heading

### Fase 2: Corrigir format! inline args
- [ ] PDF: `format!("blake3:{}", ...)` → `format!("blake3:{hash}")`
- [ ] PDF: Todos os `format!` com display() → inline args
- [ ] Verificar HTTP: todos corrigidos

### Fase 3: Testar Localmente
- [ ] `cargo fmt --all`
- [ ] `cargo clippy --all-targets -- -D warnings`
- [ ] `cargo build --release`
- [ ] `cargo test --all`

### Fase 4: Commit e Push
- [ ] Commit com todas as correções
- [ ] Push para GitHub
- [ ] Verificar CI passando

## Solução genpdf

Baseado na versão 0.2, a API correta é:
```rust
use genpdf::{fonts, Document};

// Opção 1: Usar builtin font
let font = fonts::builtin::Helvetica;

// Opção 2: Criar font family manualmente
let font = fonts::FontData::new(..., ...);

// Opção 3: Usar fonts::from_files() se disponível
```

Vou testar e corrigir.

