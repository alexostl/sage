---
title: Plan — Rename sage-codex → sage-selfhost across project artifacts
status: completed
type: fix-plan
scope: moderate
created: 2026-04-28
completed: 2026-04-28
commit: 41dbe5d
---

# Plan — Rename sage-codex → sage-selfhost across project artifacts

## Goal

Po rename'ie repo `sage-codex` → `sage-selfhost` (na poziomie filesystem
+ GitHub) projekt nadal nazywa siebie „sage-codex" w żywej wiedzy
roboczej (`.sage/docs/`, `.sage-memory/`). To propaguje się do agenta
przy SessionStart i w rezultacie nowe artefakty regenerują starą nazwę
(self-perpetuating drift). Cel: usunąć drift z aktywnych źródeł, nie
falsyfikując historii.

## Zasady cięć

- **Aktywna wiedza operacyjna** (`learn-*`, `.sage-memory/sage-codex-*`,
  `decision-sage-source-of-truth.md`, `memory-*`) → pełny rename pliku
  + `s/sage-codex/sage-selfhost/g` w treści.
- **Historia / refleksja / incident-reporty** (`analysis-*`, `reflect-*`,
  `qa-report-*`) → nazwy plików bez zmian; **nie** przepisywać body
  (zachowanie wierności wydarzeń); dodać nagłówek z notą o rename'ie.
- **Ukończone planowanie** (`.sage/work/*/spec.md`, `.sage/work/*/plan.md`,
  `decisions.md`) → nie tykać. Zamiast tego prepend nowego wpisu do
  `decisions.md`.
- **Codex platforma vs sage-codex projekt** — wzmianki o platformie
  Codex (np. `~/.codex/`, „Codex hooks", „Codex Platform Context") to
  poprawna nazwa platformy, nie projektu. Nie zmieniać.

## Zakres — pełny inwentarz

### Krok 1: Rename + content-update plików w `.sage/docs/`

**Rename (4 pliki, `git mv`):**
- `learn-sage-codex-repository-map.md` → `learn-sage-selfhost-repository-map.md`
- `learn-sage-codex-working-model.md` → `learn-sage-selfhost-working-model.md`
- `learn-sage-codex-branch-worktree-model.md` → `learn-sage-selfhost-branch-worktree-model.md`
- `learn-sage-codex-codex-platform-context.md` → `learn-sage-selfhost-codex-platform-context.md`
  (środkowe „codex" pozostaje — to nazwa platformy)

**Content-only update (1 plik):**
- `decision-sage-source-of-truth.md` — żywy ADR, pełny `s/sage-codex/sage-selfhost/g`
  + zaktualizować referencje do renamowanych plików

**Headerowa nota (3 pliki, body verbatim):**
- `analysis-selfhost-post-symlink-incident.md`
- `reflect-branch-worktree-operating-model.md`
- `qa-report-upstream-sync-main-codex-port-selfhost.md`
- `memory-branch-worktree-operating-model.md` ← *traktuję jako żywe memory,
  ale referuje do konkretnego cyklu — dam header notę + zaktualizuję
  forward-looking sekcje*

Format noty:

> **Note (2026-04-28):** Project was renamed `sage-codex` → `sage-selfhost`.
> References below preserved verbatim from when this document was written.

### Krok 2: Rename + content-update w `.sage-memory/`

**Rename (3 pliki):**
- `sage-codex-branch-worktree-operating-model.md` → `sage-selfhost-branch-worktree-operating-model.md`
- `sage-codex-codex-worktree-root.md` → `sage-selfhost-codex-worktree-root.md`
- `sage-codex-upstream-pr-flow.md` → `sage-selfhost-upstream-pr-flow.md`

**Content-update w pozostałych `.sage-memory/lrn-*.md`:**
- `lrn-codex-worktrees-belong-under-codex-root.md`
- `lrn-main-namespace-conflicts-with-main-slash-branches.md`
- `lrn-promote-repo-operation-rules-out-of-cycle-artifacts.md`
- `lrn-run-upstream-discovery-before-branch-sync.md`

(Pre-flight nie pokazał, czy mają `sage-codex` w treści — sprawdzę przy
implementacji; jeśli mają, `s/sage-codex/sage-selfhost/g`.)

**Baza `memory.db`** — sage-memory MCP store. Zostawiam bez zmian
w tym zakresie; to wewnętrzna baza i jakiekolwiek live entries
referujące „sage-codex" są wyszukiwalne pod tagami, nie nazwą.
Jeśli okaże się problemem — osobne zadanie.

### Krok 3: `.gitignore`

Aktualne whitelist:
```
!.sage/docs/learn-sage-codex-codex-platform-context.md
!.sage/docs/learn-sage-codex-repository-map.md
!.sage/docs/learn-sage-codex-working-model.md
```

Zaktualizować na:
```
!.sage/docs/learn-sage-selfhost-codex-platform-context.md
!.sage/docs/learn-sage-selfhost-repository-map.md
!.sage/docs/learn-sage-selfhost-working-model.md
!.sage/docs/learn-sage-selfhost-branch-worktree-model.md
```

(Brakujący 4. wpis wygląda na pominięcie — dodaję przy okazji.)

### Krok 4: `.sage/decisions.md`

**NIE** przepisywać istniejących wpisów. **Prepend** (po `# Decisions`
header, przed istniejącymi wpisami) nowy wpis:

```markdown
### 2026-04-28 — Project renamed: sage-codex → sage-selfhost

Repository renamed from `sage-codex` to `sage-selfhost` to reflect that
this is Sage's self-hosted instance (not a Codex-specific fork).

**What changed:**
- GitHub repo: `sage-codex` → `sage-selfhost`
- Local path: `~/Developer/sage-codex` → `~/Developer/sage-selfhost`
  (stary symlink usunięty 2026-04-28)
- Claude Code Desktop "Recent" entry posprzątany; sesje JSONL
  zmerge'owane do `~/.claude/projects/-Users-alexostl-Developer-sage-selfhost/`
- `.sage/docs/learn-sage-codex-*.md` → `learn-sage-selfhost-*.md`
- `.sage-memory/sage-codex-*.md` → `.sage-memory/sage-selfhost-*.md`

**Co zostaje pod starą nazwą (zamierzone):**
- Historyczne wpisy w tym pliku (zachowanie kontekstu — Rule 7)
- Ukończone `.sage/work/*/spec.md` i `plan.md` (deliverable historyczne)
- Headery `analysis-*`/`reflect-*`/`qa-report-*` mają notę o rename'ie,
  body verbatim
- AGENTS.md H1 „Sage — Codex Instructions" (odnosi się do platformy
  Codex, nie nazwy projektu)
- Backup'y `~/.claude/backups/`, `~/.codex/*.bak-*`, `archived_sessions/`

**Dlaczego self-host, nie codex:** „sage-codex" sugerowało, że projekt
jest portem Sage do Codex (jak osobna implementacja). Faktycznie to
self-hosted Sage z adapterem Codex jako jednym z wspieranych targetów.
Nazwa „sage-selfhost" to oddaje.
```

### Krok 5: `.tmp/codex-adapter-regression.drGXSa/`

`rm -rf .tmp/codex-adapter-regression.drGXSa/` (22 805 plików, fixture
test runu, regeneruje się).

Bonus: `rmdir ~/.codex/worktrees/sage-codex/` (pusty katalog po starych
worktree'ach — usunąć żeby reapply rename'u nie podpiął się tutaj).

## Krok 6: Verification

Po implementacji:

1. `grep -rn "sage-codex" --include="*.md" .` w roocie projektu →
   oczekiwane hity TYLKO w:
   - `.sage/decisions.md` (historyczne wpisy + nowy nagłówek mówiący
     o rename'ie — czyli słowo „sage-codex" wystąpi w kontekście wyjaśnienia)
   - `.sage/work/*/spec.md` i `plan.md` (ukończone, historyczne)
   - `analysis-*`, `reflect-*`, `qa-report-*` w `.sage/docs/` (body verbatim
     pod headerową notą)
2. `ls .sage/docs/learn-*.md` → tylko `learn-sage-selfhost-*` (4 pliki),
   żadnego `learn-sage-codex-*`
3. `ls .sage-memory/sage-*.md` → tylko `sage-selfhost-*` (3 pliki)
4. `cat .gitignore | grep learn-sage` → 4 wpisy `learn-sage-selfhost-*`
5. `git status` → wszystkie rename'y poprawnie wykryte jako `R` (nie
   delete+add — chronimy historię)
6. `head -5 .sage/decisions.md` → nowy wpis na górze
7. `ls .tmp/` → puste
8. `ls ~/.codex/worktrees/` → bez `sage-codex/`
9. SessionStart auto-inject w nowej sesji → „Recent decisions" pokazuje
   nowy wpis o rename'ie zamiast starego „`.sage` becomes... for sage-codex"

## Ryzyka

- **R1: Cross-refs niezauważone.** Pre-flight grep złapał 8 wewnętrznych
  cross-refs, ale tylko w `*.md`/`*.sh`/`*.toml`/`*.json`. Mityg.: po
  rename'ach uruchomię ponowny grep „learn-sage-codex" w całym repo,
  jeśli coś zostanie — patch.
- **R2: Git mv vs git add+rm.** Użycie `git mv` zachowuje historię.
  Mityg.: implementacja używa `git mv`, nie `mv` + `git add`.
- **R3: Filename '`learn-sage-codex-codex-platform-context.md`' →
  '`learn-sage-selfhost-codex-platform-context.md`' brzmi powtórzenie.**
  Akceptowane — środkowe „codex" odnosi się do platformy Codex.
  Alternatywa: `learn-sage-selfhost-codex-platform.md` (krótsza). Decyzja:
  zostawiam dłuższą formę dla spójności z istniejącym schematem nazw.
- **R4: `memory.db` może mieć live entries z „sage-codex".** Mityg.:
  poza scope tego planu; po implementacji uruchomię
  `sage_memory_search "sage-codex"` i jeśli będą hity — osobny task
  z `mcp__sage-memory__sage_memory_update`.
- **R5: Inne worktree'y mogą mieć stare ścieżki.** Pre-flight pokazał,
  że `~/.codex/worktrees/sage-codex/` istnieje pusty. Inne worktree'y
  pod `~/.codex/worktrees/alex-os-dev/` nie są dotknięte. Mityg.: brak.

## Out of scope

- Rename na poziomie GitHub (już zrobione, repo nazywa się sage-selfhost)
- Edycja `~/.claude/backups/`, `~/.codex/*.bak-*`, archived_sessions —
  są to historyczne snapshoty, nie touch
- Rewrite `.sage/work/*/spec.md` i `plan.md` (ukończone deliverables)
- Rewrite historycznych wpisów w `.sage/decisions.md`
- AGENTS.md H1 „Sage — Codex Instructions" (Codex = platforma, OK)

## Kolejność implementacji

1. Krok 5 (rm `.tmp/...`, rmdir worktree) — szybkie, niezależne
2. Krok 1A (`git mv` 4 plików w `.sage/docs/`) — atomowo
3. Krok 1B (content-update renamowanych + decision-sage-source-of-truth)
4. Krok 1C (header noty na 4 plikach historycznych)
5. Krok 2A (`git mv` 3 plików w `.sage-memory/`) — atomowo
6. Krok 2B (content-update memory plików + lrn-* jeśli mają hity)
7. Krok 3 (`.gitignore`)
8. Krok 4 (prepend `decisions.md`)
9. Krok 6 (verification grep + git status)

## Estimates

- Plików dotkniętych: ~15 edycji + 7 rename'ów + 1 prepend + 1 rm -rf
- Bez testów (czysto redakcyjne; verification = grep)
- Commit: jeden kompletny commit „Rename project: sage-codex → sage-selfhost"
  ALBO dwa (1: rename + content; 2: decisions.md + .tmp cleanup) — do decyzji
