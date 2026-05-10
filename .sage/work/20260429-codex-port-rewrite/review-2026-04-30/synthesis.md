---
title: "Synthesis — 3-axis review of Codex port design (ADRs 1-9)"
date: 2026-04-30
status: complete
phase: review-synthesis
review_id: review-2026-04-30
inputs:
  - agent-A1-hooks-feasibility.md
  - agent-A2-config-instructions.md
  - agent-A3-mcp-state.md
  - agent-A4-cli-doctor-profiles.md
  - agent-B-claude-parity.md
  - agent-C-gap-detection.md
  - recon-claude-bootstrap.md
  - poc-A1-uncertainties.md
gate: review-before-spec
verdict: GREEN-WITH-CONDITIONS
---

# Synthesis — 3-axis review of Codex port design

> Finalny artefakt review fazy. Konsoliduje 6 raportów + 1 recon + 1 PoC
> w jeden punch list dla autora `spec.md`. Każdy finding linkuje do
> źródłowego raportu.

## Executive verdict: GREEN with conditions

**Konkluzja jednozdaniowa:** Cała architektura ADRów 1–9 jest **realnie
buildable** — Codex udostępnia każdy mechanizm na którym ADRy się opierają,
żaden ADR nie wymyśla nieistniejących pól. Przed `spec.md` należy
zaadresować **2 krytyczne luki** (lifecycle + post-write verify) i
wprowadzić **~10 mechanicznych korekt DRIFT** w samych ADRach lub w spec.md.

| Wymiar | Wynik |
|---|---|
| BLOCKERS (Codex nie ma mechanizmu) | **0** |
| Krytyczne luki wymagające ADR/spec | **2** (generator-codex + post-write-verify) |
| DRIFT (terminology/syntax) do uściślenia | **~10** |
| UNVERIFIED zamknięte przez review | **3/3** (U1 PoC, U2 A3, U3 PoC) |
| Świadome rozbieżności udokumentowane | OK |
| Pattern systemowy do świadomej decyzji | **1** (degradacja przy MCP outage) |

## Co zostało zweryfikowane empirycznie/dokumentacyjnie

### Mechanizmy potwierdzone w docs Codex (A1+A2+A3+A4)

- **6 eventów hookowych:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`,
  `PermissionRequest`, `PostToolUse`, `Stop` — wszystkie pod nazwami z ADRów
- **Klucz `[features].codex_hooks`** istnieje (PoC: stable=true by-default,
  nie wymaga aktywacji)
- **Ścieżki konfiguracji** `<repo>/.codex/hooks.json` + `~/.codex/hooks.json`
- **Tool names:** `apply_patch`, `Edit`, `Write`, `Bash`, MCP tools z aliasami
- **`exit 2`** blokuje mutację dosłownie potwierdzone
- **Trzy pola instructions:** `developer_instructions` (string),
  `model_instructions_file` (path), `instructions` (reserved) — wszystkie
  udokumentowane jako **odrębne**, Sage używa `developer_instructions` poprawnie
- **MCP config schema:** `mcp_servers`, transports STDIO/HTTP, `enabled_tools`,
  `tool_timeout_sec`, **`required`** — wszystkie w `config-reference`
- **Profile system** `[profiles.<name>]` z `approval_policy`, `sandbox_mode`
- **Plugin = bundle skills + apps + MCP** (nowy fakt z A4)

### Mechanizmy potwierdzone empirycznie (PoC)

- **U1 — UPS forge-resistance: PASS.** Stop hook exit 2 wstrzykuje stderr
  jako kontynuację, ale UPS NIE odpala ponownie. ADR-2 token mechanism
  bezpieczny. (`stop_hook_active=true` na drugim Stop potwierdza
  strukturalnie.)
- **U3 — Multi-hook: PASS_ALL_FIRE_UNORDERED.** Wszystkie entries odpalają,
  ale **kolejność między entries jest niedeterministyczna**. Wewnątrz
  `hooks: [...]` jednego entry — sekwencyjna.
- **Codex 0.126.0-alpha.15** zweryfikowany jako baseline.
- **Schema hooks.json** dwupoziomowa:
  `{"hooks":{"Event":[{"matcher":"...","hooks":[{"type":"command","command":"..."}]}]}}`

### Codex CO NIE MA (legitne miejsce na wartość Sage)

- **Pojęcie "outcome / verification / proof"** — nie istnieje w Codex docs
  (potwierdzone 3 cytatami z A3). ADRy 2/3/4/5 słusznie budują warstwę
  której Codex sam nie ma. To nie luka, to thesis Sage.

## CRITICAL — 2 luki do zamknięcia przed spec.md

### CRIT-1 — Generator pipeline dla Codex (B+C konwergencja → recon)

**Co odkryliśmy łącznie z B, C i recon:**

1. **B `cap-bootstrap-state` + C P0 #1** zauważyły że ADRy nie mówią
   jak gate scripts (i inne pliki) trafiają z `core/` do `.sage/`
2. **B `cap-merge-constitution` + C P0 #3** zauważyły brak constitution
   merge mechanism
3. **Recon Claude bootstrap** ujawnił że **mechanika już istnieje** w
   Claude port (`generate-claude-code.sh:419-473` z
   `__CONSTITUTION_PLACEHOLDER__`, `bin/sage init` 10 atomowych kroków,
   gate scripts kopiowane explicite z `core/gates/scripts/`)
4. **Implikacja:** to nie jest "missing meta-ADR od zera" — to jest
   **brakujący odpowiednik dla Codex** (`generate-codex.sh` z analogicznym
   placeholder + reszta etapów)

**Działanie:**

Napisać **1 spec.md chapter "Codex generator pipeline"** opisujący:
- 10 etapów (parity z `bin/sage init`)
- Gdzie Codex różni się od Claude (np. `developer_instructions` zamiast
  `@-import` w CLAUDE.md, brak natywnego skill auto-discovery)
- Constitution composition jako jeden z etapów (nie osobny ADR)
- Mapping `core/<dir>` → `.sage/<dir>` z explicit listą plików

**Czy potrzebny osobny ADR-N?** Tylko jeśli generator wymaga
**decyzji architektonicznej** (np. "kopiujemy całość framework do `sage/`"
vs "symlink-w-dev-mode"). Mechaniczne kroki → spec.md, bez ADR.

**Risk:** P1 (clear template z Claude port; risk = pominięcie etapu
przez nieuwagę autora spec.md, nie risk = nie wiemy jak to zrobić).

**Owner:** autor spec.md.

**References:** [B](agent-B-claude-parity.md), [C](agent-C-gap-detection.md),
[recon](recon-claude-bootstrap.md).

### CRIT-2 — Post-write verification gates (B unique finding) — ZAMKNIĘTE

**Co B znalazł:** plugin Claude w `sage-verify.sh` orkiestrował
**hallucination-check** i **visual-gate** po mutacji plików. ADR-7 (Stop
hook checks C1–C7) i predykaty PreToolUse P1–P4 ich nie pokrywają.

**DECYZJA 2026-04-30 (user, alexostl): Opcja C — split.**

**hallucination-check** → **PORTED do Codex** jako PostToolUse hook
z MCP backend (np. `sage_verify_imports` MCP tool). Łapie nowo wstawione
importy / referencje / API calls które nie istnieją w projekcie ani
w zainstalowanych dependencies. Context-aware reasoning realizowany
przez MCP tool, nie bash shim. Wallclock cost akceptowalny — szybszy
niż test runner, łapie klasę bugów którą testy często łapią dopiero
po 30s.

**visual-gate** → **EXCLUDED z v1.** Codex CLI to terminal-first; nie
ma natywnego "screenshot komponentu" / UI-aware affordance jak Claude
w VS Code. Port byłby mechanizmem-bez-substancji. Decyzja reversible —
jeśli Codex w przyszłości doda plugin distribution path z UI awareness,
otworzyć ADR-N+M dla visual-gate.

**Implikacje implementacyjne:**
- **Nowy ADR-N+1: "Codex post-write hallucination check"** — wymagany
  bo to nowy mechanism, nie refinement istniejącego ADR. Zakres:
  PostToolUse hook predicate, MCP tool contract, graceful degradation
  gdy MCP padnie (warn-only, nie fail-closed — różnica od mutation
  guardrails L1).
- Spec.md akapit "Decision: hallucination-check ported via PostToolUse
  + MCP; visual-gate excluded from v1 (Codex CLI has no UI affordance),
  revisit if plugin distribution path adds UI awareness."

**References:** [B](agent-B-claude-parity.md) finding #2,
[A1](agent-A1-hooks-feasibility.md) (PostToolUse event confirmed in docs).

## DRIFT — uściślenia w spec.md / ADR amendementy

| # | Source | Lokacja | Drift | Działanie |
|---|---|---|---|---|
| D1 | A1 | ADR-7 (Stop hook) | `decision: "block"` = "kontynuuj turn", `continue: false` = "stop" — counter-intuitive | Przepisać przykłady JSON, dodać callout |
| D2 | A1 | ADR-7 C6 | `exit 2` w Stop NIE jest "benign print" — wstrzykuje stderr jako prompt | Skorygować opis warn-only |
| D3 | A1 | ADRy używające "PreToolUse (Bash)" | W docs: event=`PreToolUse`, matcher=`^Bash$` | Spec.md używa explicit |
| D4 | A1 | ADR-mutation-guardrail-stack | Miesza Codex hooks z `.githooks/pre-commit` w jednej warstwie | Wizualnie rozdzielić w spec.md |
| D5 | A1 + PoC | ADR-hook-activation, ADR-mutation-guardrail-stack | "Wszystkie hooki w array odpalają" — PASS, ale ordering UNORDERED | Callout: hooki **order-independent** |
| D6 | A2 | ADR używa `AGENTS_MD_MAX_BYTES` (Rust source) | Public docs: `project_doc_max_bytes` (wartość 32768 ta sama) | Cytuj public name w spec.md |
| D7 | A2 | ADR | 8000-char discovery cap to konserwatywny fallback | Uściślić: realny cap = 2% kontekstu |
| D8 | A2 | ADR-4 | "Codex deprecated slash commands 2026-01-22" niezweryfikowane | Usunąć datę lub zalinkować źródło |
| D9 | A3 | ADR-mcp-stack D5 | `startup_timeout_sec=5` przy default 10 | Zostaw default lub uzasadnij override |
| D10 | A3 | (cross) | Kolizja terminologiczna "approval" (sandbox vs workflow) | Spec.md MUSI mieć glossary |
| D11 | A3 | ADR-workflow-state-machine + ADR-approval-proof | "frontmatter + decisions.md" — brak hierarchii precedensu | Spec.md: source-of-truth precedence |
| D12 | A4 | ADR-doctor-and-status | Naming collision `bin/sage status` vs natywny `/status` | Rename lub callout |
| D13 | A4 | (cross) | Brak deterministycznego mappingu Sage labels ↔ native profile | Spec.md: mapping table |
| D14 | A4 | ADR-public-workflows-internal-library | Pomieszanie skill vs plugin (Codex docs explicit: plugin = bundle) | YELLOW — uściślić nomenklaturę |

## UNVERIFIED — wszystkie zamknięte

| ID | Source | Status | Resolution |
|---|---|---|---|
| U1 | A1 (UPS forge-resistance) | **VERIFIED PASS** | [PoC](poc-A1-uncertainties.md) — UPS fires only on real user input |
| U2 | A1 (`required = true`) | **VERIFIED OK** | [A3](agent-A3-mcp-state.md) — pole jest w `config-reference` |
| U3 | A1 (multi-hook) | **VERIFIED PASS w/CAVEAT** | [PoC](poc-A1-uncertainties.md) — wszystkie odpalają, **ordering nondet** |

**Self-flagged przez ADRy (dalej UNVERIFIED, ale ADRy mają plan):**

- A2 #UV1 — pozycje `developer` @ input[0] i `user` @ input[1] (z `client.rs`,
  nie z public docs) — ADR-1 sam to flaguje, plan v2 verification snapshot
- A3 #UV1 — `codex exec --json` schema + `--seed` flag — ADR-8 FM-8.1
  pinuje 0.126 + ma fallback
- A3 #UV2 — sandbox ↔ MCP write to `.sage/` w workspace-write — akcja:
  `sage doctor` self-test (nie PoC)
- A3 #UV3 — ADR-mcp-stack D6 (no-respawn) empirically-anchored (PoC C1 T3),
  watch przy bumpie Codex

**Risk profile:** wszystkie self-flagged są acceptable jeśli `sage doctor`
ma odpowiednie checki w v1. Spec.md powinien wymagać D2 checks E1, M3, S4.

## SYSTEMIC PATTERN — świadoma decyzja w spec.md

### Pattern: degradacja przy MCP outage (B cross-cutting)

**Obserwacja B:** Codex konsekwentnie przesuwa logikę bash → Python/MCP
(zgodnie z C3 z briefu). Konsekwencja: **runtime trudniejszy do
degradacji niż Claude**.

| Scenariusz | Claude port | Codex port (per ADR-3 D6) |
|---|---|---|
| MCP server padnie | Fallback do plików `.sage-memory/` (markdown) | Manualny `sage doctor` wymagany |
| Memory unavailable | Skille degradują się gracefully | Hooki mogą zwrócić error |
| Network issue | Local files always work | MCP-dependent flows lock |

**Pytanie:** Czy ten tradeoff jest **świadomy**? Czy ma uzasadnienie w
ADR-mcp-stack lub ADR-doctor-and-status, czy jest emergent property?

**Działanie sugerowane:**
- Jeśli świadomy → dodać sekcję "Degradation model" do ADR-9 (sage doctor)
- Jeśli nie świadomy → otworzyć dyskusję w spec.md: czy Codex powinien
  mieć fallback do plików dla critical capabilities (memory)?

**Risk:** P2 — spec.md może to zrealizować, nie blokuje implementacji.

**References:** [B](agent-B-claude-parity.md) cross-cutting patterns.

### Open question — scope:company/personal/dev artifact vs Sage presets

**Co odkryliśmy 2026-04-30:** Recon Claude bootstrap pierwotnie wymienił
4 presety Sage (`base`/`startup`/`enterprise`/`opensource`) — to jest
**potwierdzone na upstream** `https://github.com/xoai/sage`
(`core/constitution/presets/`).

User zauważył w trakcie review, że w globalnym CLAUDE.md (~/.claude/CLAUDE.md)
istnieje **inny system klasyfikacji**: `scope: company/personal/dev` we
frontmatterze AGENTS.md. **To NIE jest Sage convention** — to artefakt
zewnętrznego systemu (alex-os) który użytkownik ma w swoim setupie.

Te dwa systemy są ortogonalne:
- **Sage presets** = typ projektu kodu (startup vs enterprise vs opensource)
  → wpływa na rygor code review, deploy, governance
- **Alex-os scope** = w jakim kontekście pracuję (business / personal /
  dev kodu) → wpływa na lokalizację repo, naming convention

**Open question for spec.md (NIE agent decision):**

[Q1] Czy port Codex powinien w ogóle wspominać o `scope:` we
frontmatterze AGENTS.md?

**DECYZJA 2026-04-30 (user, alexostl): Opcja A.**
Sage Codex port nie wspomina o `scope: company/personal/dev`. Pozostaje
branżowy (presety startup/enterprise/opensource/base). Artefakt
alex-os nie ma być wstrzykiwany do upstream Sage. Spec.md ma w sekcji
"Codex generator pipeline" explicit nie wymieniać żadnego frontmatter
field `scope` — tylko Sage-native fields. Jeśli alex-os użytkownik chce
swój scope, dodaje go po stronie własnego layeru przez User Additions
zone w AGENTS.md (post-Sage-update preserve).

**Implikacja dla spec.md:** weryfikacja w `sage doctor` lint S1
(manifest of fields) musi NIE zaakceptować `scope:` jako valid Sage
field. Jeśli istnieje w istniejącej AGENTS.md projektu — info-level
warning "non-Sage field detected (likely external system); preserved
in User Additions zone if below separator".

### Pattern: plugin angle (A4 cross-cutting #3)

**Obserwacja A4:** Sage ma **wszystkie 3 składowe pluginu Codex** (skills +
apps/CLI + MCP servers). ADRy traktują Sage jako kolekcję ADRów dystrybuowaną
przez `bin/sage init`. **Czy Sage powinien być publikowany jako Codex plugin?**

**Pro:** natywna instalacja, discoverability, version management przez Codex
**Con:** wymaga compliance z plugin schema Codex (nie zbadane), uzależnienie
od Codex distribution model

**Działanie:** Otwarty temat na **discovery w spec.md** lub na osobny ADR-N+1
po spec. NIE blokuje obecnej drogi (init script).

**Risk:** P3 — możliwość przyszłej optymalizacji distribution, nie problem
obecnej architektury.

## OK / Świadome rozbieżności (no action needed)

Te elementy review potwierdziły jako poprawne / świadomie wybrane:

- 4 capabilities z B PARITY CONFIRMED
- 6 capabilities z C FULL coverage
- 7 OK-claims z A1
- 8 OK-claims z A2
- 2 OK-claims z A3
- 3 GREEN-verdict z A4
- 7 z 9 self-flagged divergences B (DOCUMENTED DIVERGENCE z uzasadnieniem
  w ADR)

## Recommended actions — punch list dla autora spec.md

**Przed otwarciem spec.md (1-2h pracy):**

1. ☐ **CRIT-2 rozstrzygnąć** — post-write verify: wykluczyć vs dodać.
   Jeśli wykluczyć → krótka nota w ADR-7 z uzasadnieniem. Jeśli dodać →
   szkic PostToolUse hook lub C8/C9.
2. ☐ **D5 callout** — multi-hook order-independent jako stała projektowa
3. ☐ **D10 glossary** — zacząć w spec.md od sekcji terminologii (approval
   sandbox vs approval workflow, plugin vs skill, status native vs sage)

**W spec.md (główna praca):**

4. ☐ **CRIT-1** — chapter "Codex generator pipeline" (10 etapów parity
   z Claude, z mapping `core/` → `.sage/`)
5. ☐ Wszystkie DRIFTy D1–D14 zaadresowane jako zmiana JSON examples /
   nazewnictwa / cytatów / opisów
6. ☐ A2 brakujący akapit: czemu Sage NIE używa `model_instructions_file`
   (defense-in-depth)
7. ☐ A3 source-of-truth precedence dla workflow state (frontmatter > decisions.md? lub odwrotnie?)
8. ☐ A4 D13 mapping table: Sage labels ↔ native Codex profile
9. ☐ Glossary z 3+ terminów kolizyjnych

**ADR amendments (osobno, po spec.md zaakceptowany):**

10. ☐ ADR-2 — dopisać niepewności rezydualne (subagent UPS, hook
    `additionalContext`) jako D-class risk do retestu przy major bump
11. ☐ ADR-mcp-stack D6 — link do PoC C1 T3 jako empirical anchor + watch
    note
12. ☐ A1 review — przepiąć CC-2 + Claim D ADR-2 z UNVERIFIED → VERIFIED
    z linkiem do PoC

**`sage doctor` D2 checks (per ADR-9 update):**

13. ☐ E1 — Codex CLI present + version check (>= 0.126)
14. ☐ M3 — sandbox-write self-test do `.sage/` (zamknij A3 #UV2)
15. ☐ S4 — manifest of files written outside MCP includes 4 new writers
    (per Batch 3 amendments)

## Process notes

**Co zadziałało:**
- 3-osiowy review (feasibility + parity + gaps) wyłapał problemy które
  jeden axis by zgubił. Bootstrap luka pojawiła się w B i C niezależnie =
  silny sygnał. Plugin angle pojawił się tylko w A4 = świeże oko.
- Splitting Agent A na 4 sub-bloki po anti-hang reset uratował review
  (pierwszy A umarł w WebFetch loops).
- PoC zamiast spekulacji dla U1/U3 dał definitywne wyniki w 247s.
- Recon Claude port przed dyskusją bootstrap zaoszczędził dyskusję — okazało się że mechanika istnieje.

**Co poprawić następnym razem:**
- A1 wystarczyłoby od razu jako 4 sub-agentów (anti-hang from start)
- Recon agent powinien iść równolegle z A-agentami, nie po (oszczędność wallclock)
- "PoC w izolowanym scratch" jako standardowy template dla weryfikacji
  empirycznej

## Sign-off

**Werdykt review:** GREEN with conditions. Autor `spec.md` może otwierać
artefakt z confidence że architektura ADRów jest realna; punch list
powyżej to skończona lista akcji do zaadresowania.

**Critical gates dla spec.md to leave review:**
- [x] BLOCKERS = 0
- [x] UNVERIFIED resolved (3/3)
- [x] Q1 (scope artifact) — Opcja A (Sage zostaje branżowy)
- [x] CRIT-2 (post-write verify) — Opcja C (hallucination-check ported via PostToolUse+MCP, visual-gate excluded v1)
- [ ] CRIT-1 (generator pipeline) — chapter w spec.md
- [ ] DRIFT D1–D14 zaadresowane (~5 do ADR amendments, ~9 do spec.md)
- [ ] ADR amendments (6 sztuk) wykonane

**Recommended workflow continuation:**
- `/sage:design` lub `/sage` — kontynuuj design phase z spec.md
- Lub `/sage:architect` jeśli CRIT-1/CRIT-2 wymagają discovery

**Files in this review:**
- [agent-A1-hooks-feasibility.md](agent-A1-hooks-feasibility.md) — 4 DRIFT, 3→0 UNVERIFIED, 7 OK
- [agent-A2-config-instructions.md](agent-A2-config-instructions.md) — 3 DRIFT, 2 UNVERIFIED self-flagged, 8 OK
- [agent-A3-mcp-state.md](agent-A3-mcp-state.md) — 1 DRIFT, 2 UNVERIFIED self-flagged, 2 OK
- [agent-A4-cli-doctor-profiles.md](agent-A4-cli-doctor-profiles.md) — 3 GREEN, 1 YELLOW, 4 cross-cutting
- [agent-B-claude-parity.md](agent-B-claude-parity.md) — 2 drift, 7 divergence, 3 mismatch, 1 missing, 4 parity
- [agent-C-gap-detection.md](agent-C-gap-detection.md) — 8 NONE / 12 PARTIAL / 6 FULL coverage, 4 P0
- [recon-claude-bootstrap.md](recon-claude-bootstrap.md) — bootstrap mechanics + constitution merge
- [poc-A1-uncertainties.md](poc-A1-uncertainties.md) — U1 PASS, U3 PASS_UNORDERED
