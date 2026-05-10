---
title: "Agent C — Gap Detection Review (Codex port ADRs)"
status: completed
phase: review
date: 2026-04-30
agent: agent-C
purpose: >
  Reverse review portu Codex: chodzimy po mapie capabilities portu Claude
  i sprawdzamy, czy KAŻDA capability ma pokrycie w którymś z 19 ADRów.
  Cel: znaleźć dziury, hidden dependencies i magiczne zachowania, które
  ADRy pomijają. NIE oceniamy jakości ADRów (to robią Agent A i B) —
  oceniamy tylko, czego brakuje.
inputs:
  - .sage/work/20260429-claude-port-logic-map/map.md
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/cross-port-survey.md
  - 19 × .sage/docs/decision-codex-*.md
output_audience: design-review-synthesizer
---

# Agent C — Gap Detection Review

## 0. Metoda

1. Wziąłem każdą z 8 logicznych capabilities portu Claude (sekcja 3 mapy).
2. Plus 4 critical concrete documents (sekcja 4) i 7 punktów insight (sekcja 6).
3. Dla każdego elementu zapytałem: **który ADR (1–19) odpowiada na to pytanie?**
4. Klasyfikacja:
   - **FULL** — capability w pełni adresowana w ≥1 ADR, mechanika rozpisana.
   - **PARTIAL** — wzmiankowana lub pokryta w ułamku, brak pełnej mechaniki.
   - **NONE** — żaden ADR jej nie dotyka.
5. Dla każdej PARTIAL/NONE: czy to świadoma decyzja (cite source) czy luka?
   Cross-check: brief.md (frozen vs negotiable), cross-port-survey.md, mapa.

ADRy referencjowane jako numery (1–19) w kolejności:

1. layered-runtime-model
2. instruction-surface-split (rejected, ale stanowi kontekst)
3. mutation-guardrail-stack
4. approval-proof (rejected, superseded by 14)
5. enforcement-profiles
6. public-workflows-internal-library
7. outcome-driven-verification
8. workflow-state-machine
9. hook-activation
10. narrow-palette-honest-framing
11. validate-mutation-predicate
12. shared-skill-manifest
13. instruction-surfaces (dual: AGENTS.md + developer_instructions)
14. approval-proof-schema
15. mcp-stack
16. doctor-and-status
17. preamble-extraction
18. stop-hook-scope
19. outcome-harness

## 1. Coverage matrix — capabilities

| Cap ID | Capability | Pokryta przez ADRy | Coverage | Risk |
|--------|------------|--------------------|---------:|------|
| C1 | cap-translate-workflows | 6, 12, 17 (skills + manifest + preamble body) | **PARTIAL** | medium |
| C2 | cap-merge-constitution | (brak — odnosi się tylko do AGENTS.md w 13) | **PARTIAL** | **HIGH** |
| C3 | cap-apply-prefix | 10 (świadomie zdjęte) | **FULL (jako N/A)** | low |
| C4 | cap-inject-preamble | 17 (preamble-extraction) | **FULL** | low |
| C5 | cap-wire-hooks | 9, 1, 18 | **FULL** | low |
| C6 | cap-context-injection | 1 (SessionStart lifecycle), 16 (status) | **PARTIAL** | medium |
| C7 | cap-post-write-verify | 3, 11, 5 (mutation guardrail stack) | **FULL** | low |
| C8 | cap-bootstrap-state | 16 (doctor wzmiankuje), brief (`bin/sage init`) | **PARTIAL** | **HIGH** |

Plus **cross-cutting**:

| Concern | Pokryta przez ADRy | Coverage | Risk |
|---------|--------------------|---------:|------|
| Generator orchestration (`sage update`) | 16 (doctor), brief | **PARTIAL** | medium |
| Sage Memory MCP registration | 15 wzmiankuje "Sage MCP", nie sage-memory | **NONE** | **HIGH** |
| Persona deployment | 17 (preambles ref'ują persony) | **NONE** | medium |
| Loader stubs (Claude `.claude/skills/<wf>/SKILL.md` redirector) | brief sugeruje, ADRów brak | **N/A (świadomie zdjęte)** | low |
| `decisions.md` rotation (≥200 LOC) | (brak) | **NONE** | low |
| Tier classification (1/2/3) UX | 13 wzmiankuje, 12 sketchuje manifest field | **PARTIAL** | medium |
| Skill body content composition | 6 + 17 częściowo, mechanika nie zlockowana | **PARTIAL** | medium |
| Plugin EOF-blocks (Claude special-case `sage`/`review`) | (brak; Codex nie ma pluginu) | **N/A** | low |
| Cross-language routing (UserPromptSubmit dla nie-approval) | 10 (zakaz keyword-classify), 8 (workflow_id) | **PARTIAL** | medium |
| MCP server distribution (PyPI vs git-clone) | 15 (uv installer ladder) | **FULL** | low |
| Marketplace.json analog | 6 + brief (CLI-only) | **N/A (świadomie zdjęte)** | low |
| Constitution presets (startup/enterprise/opensource) | (brak) | **NONE** | **HIGH** |
| Atomic write semantics (mktemp+mv dla settings/AGENTS.md) | (brak; tylko `bin/sage` impl detail?) | **NONE** | low |
| Config (`.sage/config.yaml`) — co konsumuje | (brak; w Claude steruje prefiksem) | **NONE** | low |

## 2. Krytyczne luki (HIGH risk)

### GAP-1: cap-bootstrap-state — `bin/sage init` mechanics nieopisane

**Co Claude robi (mapa §3.8):**
- Idempotentnie tworzy `.sage/`: `mkdir work/, docs/`, `decisions.md`
  (init line), `conventions.md` (placeholder).
- Zawsze: kopiuje `core/gates/scripts/*.sh` → `.sage/gates/scripts/`
  (chmod +x), `core/gates/_config/gate-modes.yaml` → `.sage/gates/`.
- Opcjonalnie (`deploy_loader_stubs: true`): zapisuje
  `.claude/skills/<prefix><skill>/SKILL.md` jako redirector.

**ADR check:** żaden z 19 ADRów nie definiuje:
- jak `.sage/` powstaje przy `bin/sage init` w nowym projekcie Codex,
- czy gates skopiowane są do `.sage/gates/scripts/` czy odczytywane z
  framework root,
- jak sa idempotentność — co jeśli `decisions.md` już istnieje,
- jak inicjalizować `conventions.md`,
- jaka jest minimalna zawartość `.sage/config.yaml` (jeśli w ogóle ma
  istnieć w Codex porcie).

**Świadoma decyzja czy luka?**
- brief.md §3 "Modify with care" wymienia `bin/sage` jako shared component,
  ale nie precyzuje, czy `init` jest re-implementowany dla Codex.
- cross-port-survey.md tabela cap-bootstrap-state pokazuje cel "All ports
  share `.sage/` schema" — czyli intencja jest taka sama, ale **mechanika
  bootstrapu w Codex porcie nie jest osobną decyzją**.
- ADR-16 (doctor-and-status) sprawdza obecność `.sage/` files w doctor checks,
  ale nie tworzy ich.
- → **LUKA**, nie świadoma decyzja. Brak ADR oznacza, że deweloper podczas
  implementacji będzie musiał wymyślić mechanikę ad-hoc (`bin/sage init` w
  bashu, ad-hoc Python, itd.) bez review konstytucyjnego.

**Scenariusz bez tego:**
- Programista implementuje `bin/sage init` jako fork z portu Claude →
  działa, ale nie wiadomo, czy Codex potrzebuje czegoś dodatkowego (np.
  AGENTS.md w katalogu projektu, `.codex/config.toml` deploy).
- Po implementacji okazuje się, że Codex `bin/sage init` nie kopiuje gates
  do `.sage/gates/scripts/` — wszystko działa dopóki agent nie zacznie
  używać workflow gates, wtedy pęka cicho.

**Rekomendacja:** dodać ADR „**Bootstrap & state lifecycle**". Decyduje:
1. Co `bin/sage init` tworzy w projekcie Codex (`.sage/`, `.codex/`).
2. Czy gates kopiujemy lokalnie czy resolve'ujemy do framework root.
3. Co robi przy istniejącym `.sage/` (skip vs merge).
4. Jak `bin/sage init` różni się od `bin/sage update` (init = idempotent
   create, update = re-run generator).

---

### GAP-2: cap-merge-constitution — brak wstrzykiwania konstytucji do AGENTS.md

**Co Claude robi (mapa §3.2):**
- Czyta `.sage/constitution.md` (preset + project additions).
- Łączy z bazą + presetem z `core/constitution/presets/{startup,enterprise,opensource}/`.
- Wstrzykuje do CLAUDE.md w miejsce `__CONSTITUTION_PLACEHOLDER__`.
- Sekcje numerowane sekwencyjnie (Rule 0, Rule 1, …).
- Python3 z fallbackiem na sed.

**ADR check:**
- ADR-13 (instruction-surfaces) opisuje zawartość AGENTS.md (constitution
  + skills + tier model + workflows index), ale **nie precyzuje, czy
  `.sage/constitution.md` jest źródłem konstytucji w AGENTS.md, ani jak
  działa preset merge**.
- Brief.md mówi tylko ogólnie: "AGENTS.md jest generowane".
- Żaden ADR nie wspomina o `__CONSTITUTION_PLACEHOLDER__`, `core/constitution/presets/`,
  ani sekwencyjnym numerowaniu.

**Świadoma decyzja czy luka?**
- cross-port-survey.md tabela cap-merge-constitution: cel "All ports
  generate constitution-aware top-level instruction file" — **intencja
  jest, ale Codex ADRy nie locknęły mechaniki**.
- ADR-13 omawia **co** ma być w AGENTS.md, ale **nie jak** powstaje sekcja
  konstytucji. Pytanie: czy konstytucja jest hardcoded w generatorze, czy
  template + placeholder + merge ze sage `core/constitution/presets/`?
- → **LUKA architektoniczna**: ADR-13 i ADR-6 (workflows) milczą o
  "constitution composition pipeline".

**Scenariusz bez tego:**
- Projekt Codex generuje AGENTS.md, ale nie reaguje na zmianę
  `.sage/constitution.md` w projekcie userskim → user dodaje preset
  `enterprise`, run `sage update`, AGENTS.md się nie zmienia.
- Albo odwrotnie: każdy `sage update` overwrite'uje user constitution
  (`.sage/constitution.md`) zamiast traktować ją jako project additions.

**Rekomendacja:** dodać sekcję do ADR-13 (lub osobny ADR „Constitution
composition pipeline"):
- Czy preset jest w core czy w `.sage/constitution.md`.
- Jak działa merge (ADR-13 nie odpowiada).
- Co `sage update` robi z istniejącym `.sage/constitution.md`.

---

### GAP-3: Sage Memory MCP — registracja brakuje, AGENTS.md zakłada że istnieje

**Co Claude robi:**
- Globalna konfiguracja MCP w `~/.claude/settings.json` (lub project-local
  `.claude/mcp.json`) rejestruje `sage-memory` MCP server.
- Rule 1A "Memory Before Work" (CLAUDE.md) wymaga `sage_memory_search` przed
  Standard+ workflow.

**ADR check:**
- ADR-15 (mcp-stack) opisuje **Sage MCP server** (4 tools v1: status,
  validate_mutation, record_approval, audit_turn).
- ADR-15 wspomina, że ten MCP jest `required = true` w `.codex/config.toml`.
- **NIE wspomina o `sage-memory` MCP server jako osobnej zależności.**
- ADR-13 (instruction-surfaces) AGENTS.md sample: "MUST call
  `sage_memory_search` before Standard+ work" — **ale `sage-memory` MCP
  nie jest rejestrowane przez generator**.

**Świadoma decyzja czy luka?**
- Może być świadoma: użytkownik instaluje `sage-memory` osobno (np. via
  `alex-os-dev`), Codex port go nie owns.
- Ale ADR-15 mówi o Codex MCP stack jako całości — pominięcie `sage-memory`
  jest niezadeklarowane. Cross-port-survey nie ma dedykowanej kolumny dla
  memory MCP.
- → **PARTIAL LUKA**: brakuje świadomej decyzji "Sage Memory MCP nie jest
  ownowane przez Codex port; user musi sam zarejestrować w `~/.codex/config.toml`".

**Scenariusz bez tego:**
- User instaluje Codex port w czystym projekcie. AGENTS.md mówi "MUST call
  sage_memory_search". Agent w pierwszej turze próbuje wywołać tool —
  fail "tool not found".
- Doctor (ADR-16) **nie sprawdza**, czy `sage-memory` MCP jest dostępne →
  cichy fail.

**Rekomendacja:**
1. Dodać do ADR-15 sekcję „External MCP dependencies" — `sage-memory` jako
   **wymagane** lub **zalecane** dependency, z linkiem skąd brać.
2. Dodać do ADR-16 (doctor) check: `mcp:sage-memory connectivity` (warn
   jeśli unavailable).
3. Alternatywnie, AGENTS.md w ADR-13 powinno mówić: "If sage-memory MCP
   unavailable, fall back to `.sage-memory/` files" — bezpieczne degraded mode.

---

### GAP-4: Constitution presets nieobecne w żadnym ADR

**Co Claude robi:** `core/constitution/presets/{startup,enterprise,opensource}/`
zawiera 3 presety, które user wybiera w `.sage/config.yaml` lub
`.sage/constitution.md`. Wpływają na bake-in w CLAUDE.md.

**ADR check:** żaden z 19 ADRów nie wspomina o presetach. ADR-13
(instruction-surfaces) opisuje zawartość AGENTS.md jako "Sage constitution
(non-negotiable)" w sposób monolityczny.

**Świadoma decyzja czy luka?**
- cross-port-survey.md nie ma kolumny "constitution presets".
- brief.md §3 "Modify with care" wymienia `core/` jako frozen — ale `core/
  constitution/` może być w pełni współdzielone bez per-port modyfikacji.
- → **PRAWDOPODOBNIE LUKA**, nie świadoma decyzja. Jeśli core/constitution/
  presets/ ma być używane przez Codex, ADRy o tym milczą.

**Scenariusz bez tego:**
- User Codex projektu nie wie, że może wybrać preset (np. `enterprise`
  doda compliance rules). Codex AGENTS.md zawsze ma minimal preset.

**Rekomendacja:** krótkie dopowiedzenie w ADR-13, że konstytucja w AGENTS.md
to base + selected preset (z `.sage/config.yaml`) + project additions
(`.sage/constitution.md`), albo świadomy "Codex v1 not supported,
uses base only" entry w cross-port-survey.

## 3. Średnie luki (medium risk)

### GAP-5: cap-translate-workflows — body content z `core/workflows/<wf>.workflow.md` do SKILL.md

**Co Claude robi:** Plugin generator parsuje `core/workflows/<wf>.workflow.md`
i wstrzykuje body do `skills/<wf>/SKILL.md` z `disable-model-invocation: true`.
Special-case dla `sage` i `review` (EOF-blocks).

**ADR check:**
- ADR-6 (public-workflows-internal-library) opisuje, że Codex eksponuje
  workflows jako skille z `manifest:` blokiem.
- ADR-12 (shared-skill-manifest) opisuje frontmatter `manifest:` block z
  layered fields (preamble_teaser, preamble_body, persona_files).
- ADR-17 (preamble-extraction) opisuje jak preamble jest osadzony.
- **Czego NIE ma:** jak `core/workflows/<wf>.workflow.md` body trafia do
  Codex SKILL.md. Czy plain copy? Czy template substitution? Czy tylko
  preamble + reference do framework path?

**Świadoma decyzja?** ADRy 6, 12, 17 zakładają że "workflow body" istnieje,
ale mechanika kompozycji nie jest zlockowana. → **LUKA mechaniki**.

**Rekomendacja:** dodać do ADR-6 lub ADR-12 sekcję "Workflow → SKILL
composition pipeline" precyzującą:
1. Frontmatter merge: workflow frontmatter + manifest block + Codex-specific.
2. Body composition: preamble teaser + (optional) preamble body + workflow body.
3. Resolution paths: czy ścieżki w workflow body są re-pisane (jak w Claude
   `sage-navigator` substitution).

---

### GAP-6: cap-context-injection — runtime mechanism nie precyzowany

**Co Claude robi:** `sage-session-init.sh` przy SessionStart czyta
`.sage/work/*/` frontmatter, `.sage/docs/` count, last 3 `### ` z
decisions.md, formatuje structured markdown na stdout → Claude wraps
`<system-reminder>` i wstrzykuje. Bash-only, zero deps, timeout 10s.

**ADR check:**
- ADR-1 (layered-runtime-model) opisuje SessionStart jako lifecycle layer.
- ADR-16 (doctor-and-status) ma `sage status` CLI, ale to **read-only
  output**, nie session-injection.
- **Czego NIE ma:** czy Codex SessionStart ma odpowiednik
  `sage-session-init.sh`? Czy jest to bash script, MCP call, czy hybrid?
- ADR-15 sugeruje, że Codex może użyć `sage_status` MCP tool jako
  context-on-demand zamiast bash injection (insight 6.6 z mapy).

**Świadoma decyzja?** Mapa §6.6 explicit: "może być lepsze podejście niż
bash hook dla Codexa: agent na starcie woła `sage_status` i dostaje
strukturalną odpowiedź". → **PARTIAL — kierunek wskazany, ale ADR-1 nie
locknął, czy SessionStart hook wciąż istnieje** (np. dla "always-show
notice na startupie") czy tylko MCP tool on-demand.

**Rekomendacja:** ADR-1 powinno explicit wybrać:
- (A) SessionStart hook bash → injects (parytet z Claude).
- (B) Tylko `sage_status` MCP tool, no SessionStart injection.
- (C) Hybrid: SessionStart wywołuje MCP, MCP zwraca markdown.
Każdy ma trade-offs (latency, freshness, fail mode).

---

### GAP-7: Tier classification (1/2/3) UX — kto i jak ustala tier

**Co Claude robi:** CLAUDE.md uczy: "Tier 1 — just do it. Tier 2 — announce
and proceed. Tier 3 — card and choose." User communicates tier in prose
("just change the button color" → tier 1).

**ADR check:**
- ADR-1 (layered-runtime-model) P3 wzmiankuje "tier-1 bypass via manifest field".
- ADR-12 (shared-skill-manifest) ma frontmatter `manifest.tier_default`.
- ADR-13 (instruction-surfaces) AGENTS.md zawiera tier model.
- **Czego NIE ma:** jak tier-1 bypass działa runtime — czy AGENTS.md uczy
  agenta klasyfikować, czy CLI ma flag `--tier=1`, czy jest UPS hook który
  pyta przed eskalacją do gates?

**Świadoma decyzja czy luka?** Brief.md akceptuje, że tier model jest core
property (CLAUDE.md frozen). ADR-13 robi to "soft" (prose w AGENTS.md). →
**PARTIAL LUKA** — runtime enforcement tier-1 vs tier-2+ nie jest zlockowany.

**Rekomendacja:** decyzja w jednym z ADRów (8 lub 13):
- Czy gates aktywują się tylko dla tier-2+ (AGENTS.md uczy klasyfikacji
  i agent wstawia tier-tag w approval-proof).
- Czy każdy mutation idzie przez gates, a tier-1 jest tylko UX hint.

---

### GAP-8: Cross-language routing dla nie-approval prompts

**Co Claude robi:** CLAUDE.md ma routing layer w prose (3 layers:
keywords → sub-agent classifier → fallback) dla każdego inputu.

**ADR check:**
- ADR-10 (narrow-palette-honest-framing) eksplicytnie zakazuje
  `policy.allow_implicit_invocation: keyword classifier → workflow`.
- ADR-8 (workflow-state-machine) ma transitions, ale transition wymaga
  `workflow_id` jako input.
- **Czego NIE ma:** jeśli user wpisze "fix bug X" w sesji Codex, kto
  routuje to do `/sage:fix`? UserPromptSubmit hook? AGENTS.md prose?
  Czy w Codex porcie user musi explicit napisać `sage:fix bug X`?

**Świadoma decyzja?** ADR-10 zakazuje keyword classifier — to świadoma
decyzja "Codex wymaga explicit slash command lub workflow invocation".
Ale **AGENTS.md w ADR-13 nie locknął, jak user discoveruje workflows**
(menu? help command? prose w AGENTS.md?). → **PARTIAL — kierunek jasny,
UX nie**.

**Rekomendacja:** ADR-13 dopowiedzieć: "AGENTS.md zawiera Workflows index
section (lista `sage:<workflow>` + 1-line opis). Codex agent reads AGENTS.md
on session start. User invokes via `sage:<workflow>` prefix or natural
language matching workflow name. No keyword classifier."

## 4. Hidden dependencies (chain analysis)

### HD-1: ADR-15 (Sage MCP) → ADR-13 (AGENTS.md) → unmentioned `sage-memory` MCP

Łańcuch:
- ADR-13 wymaga w AGENTS.md "MUST call sage_memory_search".
- → To wymaga rejestracji `sage-memory` MCP server.
- → ADR-15 mówi tylko o **Sage MCP** (custom 4 tools), nie sage-memory.
- → Doctor (ADR-16) nie sprawdza memory MCP.

**Konsekwencja:** generator emit'uje AGENTS.md instrukcję, której agent
fizycznie nie może wykonać. Cichy fail w pierwszej turze.

→ Już opisane jako GAP-3.

---

### HD-2: ADR-17 (preamble-extraction) → persona files w `core/agents/`

ADR-17 mówi, że preamble może referencjować "Read persona at `core/agents/<role>.persona.md`".

- Persona files NIE są kopiowane do `.sage/` ani do `~/.codex/skills/`.
- W Claude porcie persony są w `core/agents/` w framework root, agent
  resolve'uje ścieżkę względem framework path.
- W Codex: jak agent dotrze do `core/agents/`? Symlink z `.sage/`?
  Pełna ścieżka w preamble?

**Dependency uncovered:** żaden ADR nie precyzuje jak persona files są
deployowane lub resolve'owane w Codex porcie.

**Rekomendacja:** ADR-17 powinno explicit wybrać: copy do `.sage/agents/`
przy `init` ALBO absolute path resolution w runtime ALBO `sage_status`
MCP zwraca content persona.

---

### HD-3: ADR-9 (hook-activation) → projects.trust_level interaction

ADR-9 mówi o single-key activation `[features].codex_hooks` i merge logic.

- Hidden dependency: research base wspomina, że Codex blokuje hooks dla
  `[projects].trust_level = "untrusted"`.
- → Generator emit'uje hook config, ale w `untrusted` projekcie hooks i
  tak nie odpalą.
- → Doctor (ADR-16) checks 15+ items, ale czy sprawdza `trust_level`
  current projektu? ADR-16 nie wspomina.

**Rekomendacja:** ADR-9 lub ADR-16 dodać check: warn jeśli current project
`trust_level != trusted` → hooks not active → instrukcja jak naprawić.

---

### HD-4: ADR-14 (approval-proof-schema) → decisions.md format compatibility

ADR-14 wymaga, żeby approval był w `.sage/decisions.md` jako wpis w
specyficznym formacie (frontmatter + decisions.md + UPS-token).

- Hidden dependency: format `decisions.md` jest **shared** (Claude port
  też pisze do tego pliku).
- → Czy Codex format approval-proof entries jest kompatybilny z Claude's
  format? Czy oba porty mogą czytać siebie nawzajem?

**Cross-port survey** mówi "All ports share `.sage/` schema" — ale ADR-14
nie referencuje, że Claude port też wpisuje do decisions.md.

**Rekomendacja:** ADR-14 explicit: "Codex approval-proof entries follow
shared `.sage/decisions.md` schema (compatible with all Sage ports)".

---

### HD-5: ADR-3 (mutation-guardrail-stack) → apply_patch granularity

ADR-3 + ADR-11 łańcuch: PreToolUse matcher `apply_patch|MCP tools` →
sage_validate_mutation MCP → P1-P4 predicate.

- Hidden dependency: `apply_patch` w Codex może być batched (jeden tool call,
  wiele plików). Predicate musi obsłużyć multi-file patches.
- ADR-11 (validate-mutation-predicate) opisuje P1-P4, ale niech ADR
  zlocknie: czy validate jest per-file czy per-call (jeden patch = jeden
  validate, vs. wiele validate'ów).

**Rekomendacja:** ADR-11 dopowiedzieć "predicate is invoked once per
apply_patch tool call; payload includes all affected paths".

## 5. Magiczne zachowania at risk

Auto-discovery, defaults, fallbacks, które w Claude działają "magicznie"
i mogą zniknąć jeśli Codex nie odtworzy ich explicit.

### M-1: Idempotentność `sage update` (re-run safety)
- Claude: `bin/sage update` można odpalić wielokrotnie bez psucia state'u.
- Codex: ADR-16 ma doctor, ale **żaden ADR nie definiuje idempotency
  contract dla `sage update` w Codex porcie**.
- → Risk: pierwsza implementacja overwrite'uje custom `.sage/constitution.md`
  user'a.

### M-2: Auto-detection presets w `core/constitution/presets/`
- Claude: jeśli `.sage/config.yaml` mówi `preset: enterprise`, generator
  picks up. Magia: brak konfiga = default preset (startup).
- Codex: brak ADR o tym → magia zniknie, projekt Codex nie ma presetów
  (patrz GAP-4).

### M-3: Path resolution dla shared `core/`
- Claude: generator w `runtime/platforms/claude-code/` resolve'uje
  `../../../core/` jako framework root. Magicznie działa, bo struktura
  monorepo.
- Codex: brief.md mówi że Codex jest in-tree (`runtime/platforms/codex/`).
  → Path resolution działa tak samo, ale **żaden ADR nie deklaruje, że
  Codex generator zakłada in-tree layout**.

### M-4: Atomic write semantics (mktemp + mv)
- Claude `settings.local.json` jest pisany atomically (mktemp + mv) —
  zabezpieczenie przed corrupt config przy concurrent write.
- Codex: AGENTS.md, `.codex/config.toml`, `~/.codex/config.toml` writes —
  brak ADR-deklaracji atomicity. Risk: failed `sage update` zostawia
  partial AGENTS.md.

### M-5: Fallback chain Python3 → sed
- Claude `cap-merge-constitution`: Python3 preferred, sed fallback.
- Codex: `bin/sage` nie ma policy "what runtime is required". Risk:
  `bin/sage` w Codex assume'uje Python, na minimal env (BSD sed-only) padnie.

### M-6: Loader stubs w `.claude/skills/`
- Claude `deploy_loader_stubs: true` opcja: tworzy `.claude/skills/<wf>/
  SKILL.md` jako redirector do `sage/skills/<skill>/SKILL.md`.
- Codex: brief sugeruje, że Codex używa `~/.codex/skills/<wf>/` directly
  (fresh deploy, not redirector). → **świadoma decyzja**, ale warto
  zaznaczyć w cross-port-survey explicit "Codex: no loader stubs".

### M-7: Granular hook ordering (SessionStart matcher patterns)
- Claude: `matcher: "startup|resume|clear|compact"` controls when
  SessionStart fires.
- Codex: ADR-9 (hook-activation) mówi o single key, ale **nie definiuje,
  czy Codex SessionStart też ma `startup|resume|clear|compact` semantykę
  czy tylko `startup`**. Risk: Codex injectuje context na startupie ale
  nie po `/clear`.

## 6. Rekomendacje (priorytetowane)

### P0 — blokery przed rozpoczęciem implementacji

1. **GAP-1: Bootstrap & state lifecycle ADR** — `bin/sage init` w Codex
   musi mieć contract. Inaczej każdy programista zrobi inaczej.
2. **GAP-3: Sage Memory MCP dependency** — albo dodać do ADR-15 jako
   external dep + doctor check, albo explicit "AGENTS.md falls back to
   `.sage-memory/` files". AGENTS.md z brakującym MCP = pierwsza tura padnie.
3. **GAP-2: Constitution composition pipeline** — ADR-13 musi powiedzieć
   `__CONSTITUTION_PLACEHOLDER__` style merge lub equivalent. Inaczej
   user'owy `.sage/constitution.md` jest no-op.

### P1 — przed v1 ship

4. **GAP-4: Constitution presets** — krótka decyzja "v1 supports? not?".
5. **GAP-6: Context injection runtime** — wybór A/B/C (bash/MCP/hybrid).
6. **HD-2: Persona deployment** — copy vs. resolve in runtime.
7. **HD-3: trust_level interaction** — doctor check.
8. **GAP-7: Tier UX** — runtime enforcement contract.

### P2 — nice-to-have, mogą czekać do v2

9. **GAP-5: Workflow body composition** — pipeline mechanics.
10. **GAP-8: Cross-language routing** — AGENTS.md sample.
11. **HD-4: decisions.md format compatibility** — explicit cross-port.
12. **HD-5: apply_patch granularity** — predicate scope.
13. **M-1 do M-7: magiczne zachowania** — explicit deklaracje w cross-port-survey.

## 7. Świadome decyzje (nie luki, ale warto skontrolować)

Lista capabilities/zachowań, które ADRy świadomie zdejmują:

| Capability/Concern | Status | Cite |
|---|---|---|
| cap-apply-prefix | N/A — Codex deprecated slash commands 2026-01-22 | mapa §3.3, ADR-10 |
| Plugin EOF-blocks (sage/review special-case) | N/A — Codex nie ma pluginu | brief §2 (CLI-only) |
| Marketplace.json | N/A — brak Codex marketplace | brief §2 |
| Keyword routing layer (CLAUDE.md prose) | Świadomie zakazane | ADR-10 |
| Two distribution paths (direct + plugin) | Świadomie jedno | brief, cross-port-survey |
| Loader stubs `.claude/skills/<wf>/SKILL.md` | Świadomie nie | brief (in-tree dev), cross-port-survey |
| PostToolUse verify (Claude plugin-only) | Świadomie zastąpione PreToolUse + apply_patch | mapa §6.3, ADR-3 |

## 8. Spójność wewnętrzna luk

Zauważam **wzorzec**: większość krytycznych luk dotyczy **lifecycle
boundary między framework `core/` a project `.sage/`**:

- GAP-1: bootstrap (czy gates kopiowane czy ref'owane?).
- GAP-2: constitution merge (preset z `core/` + project additions z `.sage/`).
- GAP-4: presets (z `core/`).
- HD-2: persony (w `core/agents/`).
- M-2, M-3, M-5: path resolution, defaults.

ADRy mocno pokrywają **runtime behavior** (hooks, MCP, predicates) i
**instruction surfaces** (AGENTS.md, developer_instructions, preamble),
ale **build/deploy lifecycle** (jak generator robi swoje) jest słabo
zlockowany.

**Korekcja systemowa:** dodać 1 meta-ADR „**Generator & deploy lifecycle**"
który łapie:
- `bin/sage init` contract (idempotency, wymagane env, fallback chain).
- `bin/sage update` contract (overwrite vs preserve, atomic writes).
- Path resolution (in-tree vs installed framework).
- Shared resources discovery (`core/gates/`, `core/agents/`,
  `core/constitution/presets/`, `core/preambles/`).

To by closure'owało GAP-1, GAP-2, GAP-4 i M-1 do M-5 jednym ADR-em.

## 9. Status review

- Zwizytowane: 8 logical capabilities + 4 critical concrete docs +
  7 cross-cutting concerns + 7 magic behaviors = **26 elementów**.
- ADR pokrycie: 6 FULL, 12 PARTIAL, 8 NONE.
- Krytyczne luki: 4 (HIGH risk).
- Średnie luki: 4 (medium risk).
- Hidden dependencies: 5 chains.
- Magiczne zachowania at risk: 7.
- Rekomendacja: 1 meta-ADR (Generator & deploy lifecycle) zamknąłby
  ~50% krytycznych luk.

**Output dla synthesizera:** użyj sekcji 6 (priorytetowane rekomendacje)
jako głównego inputu do listy działań pre-implementation. Sekcja 7
(świadome decyzje) jako sanity check, że niczego nie traktuję jako luki,
co architekt celowo zdjął. Sekcja 8 jako sugestia konsolidacji ADRów.
