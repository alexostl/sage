---
title: "Agent B — ADR Codex ↔ Claude ontology parity review"
date: 2026-04-30
reviewer: agent-B (claude-parity)
inputs:
  - .sage/work/20260429-claude-port-logic-map/map.md
  - .sage/work/20260429-codex-port-rewrite/cross-port-survey.md
  - 19 ADRów Codex w .sage/docs/decision-codex-*.md
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - CLAUDE.md (project constitution)
scope: >
  Behavioral parity review między portem Codex (faza design, 19 ADRów)
  a portem Claude jako kanonicznym opisem stanu obecnego (8 capabilities
  + 5 modułów + 3 distribution targets).
out_of_scope:
  - Ocena "czy Codex jest lepszy" (to nie tutaj)
  - Inwestygacja sprzeczności wewnątrz samych ADRów Codex (agent A)
  - Confrontacja z dokumentacją Codex / research base (agent C)
---

# Agent B — ADR Codex ↔ Claude ontology parity review

## Verdict summary

- **BEHAVIORAL DRIFT (nieświadomy, do złapania): 2**
- **DOCUMENTED DIVERGENCE (świadomie inaczej, ADR uzasadnia): 7**
- **TERMINOLOGY MISMATCH (te same koncepty, różne nazwy): 3**
- **MISSING CAPABILITY (Claude ma X, Codex pomija): 1**
- **PARITY CONFIRMED: 4**

Łącznie: 17 znaczących zogniskowanych obserwacji + 1 cross-cutting
pattern (Codex polega na MCP+hookach gdzie Claude polega na bash+tekście).

Najważniejsze do działania:

1. **DRIFT — `cap-apply-prefix` zniknął bez zastępczej decyzji o
   namespace skill mention**. Brief mówi że "Codex po deprecacji slash
   commands ma skill mentions". Ale ADRy nie odpowiadają wprost: jak
   działa namespace `$build` vs zwykły skill `build` w cudzym projekcie?
   Brak ADR'u pt. "skill namespace strategy on Codex".
2. **DRIFT — direct deploy `.claude/` ↔ Codex single path**. Mapa Claude
   jasno pokazuje że plugin i direct deploy to DWIE ścieżki dystrybucji
   z różnym pokryciem (PostToolUse plugin-only). Codex idzie w jedną
   ścieżkę (per ADR-3 + ADR-5). To jest świadoma decyzja Brief §6.1
   (uproszczenie), ale **nie ma ADR'u który by to spisał wprost**.
   Brak: "ADR — Codex distribution target (single)".
3. **MISSING — bootstrap-state idempotent copy of `core/gates/scripts/`**.
   Mapa §3.8 mówi że port Claude **zawsze** kopiuje gate scripts do
   `.sage/gates/scripts/`. ADRy Codex tego NIE wspominają. Brief Want-Have
   też nie. Cross-port survey §1.3 / §3 mówi że to wspólna baza
   wszystkich portów. Pytanie: czy `bin/sage init` na Codex robi to też?
   Jeśli nie — workflow gates nie odpalą.

Poniżej szczegóły per-capability.

---

## Findings — capability by capability

### Capability 1: `cap-translate-workflows` (mapa §3.1)

**Claude robi to przez:** Generator `generate-claude-code.sh` iteruje
`core/workflows/*.workflow.md` i emituje:
- direct: `.claude/commands/<prefix><name>.md` (frontmatter
  przepuszczony, `$ARGUMENTS` placeholder, ścieżki podstawiane do
  `sage-navigator` i `skills/`).
- plugin: `tools/sage-claude-plugin/skills/<wf>/SKILL.md`
  z `disable-model-invocation: true`.

**ADR Codex zakłada:** ADR-4 (shared skill manifest) + ADR-6 (preamble
extraction). Generator iteruje `core/_compile/skills.compiled.json`
filtrując `public: true AND "codex" in platforms`, emituje
`.agents/skills/<name>/SKILL.md` z `description: <teaser ≤300 chars>`
+ body (full preamble + workflow content) below frontmatter. Per-skill
opcjonalnie `agents/openai.yaml` z `policy.allow_implicit_invocation`.

**Verdict:** DOCUMENTED DIVERGENCE.

**Detail:**
- Codex generuje **jeden format** (SKILL.md) zamiast dwóch (komenda +
  plugin SKILL). Cross-port-survey §3 Q1 + brief V2 ("outcome parity,
  mechanism divergence") to uzasadnia: Codex po deprecacji slash
  commands 2026-01-22 nie ma slash commands jako konceptu (decision-
  codex-instruction-surface-split.md mówi to wprost).
- Codex dodaje **dwie warstwy w SKILL.md** (teaser w `description:`
  loaded at discovery, body loaded at mention). To jest **architectural
  improvement** wynikający z 8000-char cap (research base §4.3). Claude
  nie ma takiego cap, więc nie potrzebuje warstw.
- Codex używa shared manifest jako single source of truth (ADR-4 §G3).
  To jest świadoma poprawka **na slabość Claude** — mapa §6.2 mówi że
  preamble case statement w bash + awk parsing to fragile coupling.
  Codex eliminuje to przez `skills.compiled.json` + `core/preambles/`.

**Impact:** Pozytywny dla użytkownika. Zero behavioral cost — agent
widzi swoje workflow tak samo, niezależnie od portu.

**Suggested action:** ZOSTAW. Decyzja udokumentowana w ADR-4 §Why
frontmatter, ADR-6 Q2.

---

### Capability 2: `cap-merge-constitution` (mapa §3.2)

**Claude robi to przez:** Czyta `.sage/constitution.md` (preset +
project additions), łączy z bazą + presetem z `core/constitution/
presets/`, wstrzykuje do CLAUDE.md w miejsce `__CONSTITUTION_PLACEHOLDER__`.
Numerowanie sekwencyjne. Python3 z fallbackiem na sed.

**ADR Codex zakłada:** Pośrednio przez ADR-5 (instruction surfaces)
+ ADR-9 (canonical-rules.yaml). AGENTS.md ma `Cross-skill rules (7)`
z compliance lines, generowane z `runtime/platforms/codex/templates/
canonical-rules.yaml`. Też wstrzykuje `[features].codex_hooks = true`
i `[mcp_servers.sage]` block do `.codex/config.toml`.

**Verdict:** TERMINOLOGY MISMATCH + nieczęsty drift.

**Detail:**
- Claude ma **`.sage/constitution.md`** jako per-project additions
  + presety w `core/constitution/presets/` (mapa §3.2). To pozwala
  użytkownikowi rozszerzać konstytucję bez edycji CLAUDE.md.
- ADRy Codex **nie wspominają** o `core/constitution/presets/` ani
  `.sage/constitution.md`. ADR-5 mówi tylko o "Cross-skill rules (7)"
  jako STATIC content + canonical-rules.yaml jako template source.
- ADR-5 §"AGENTS.md content" tabela ma "Header" / "Cross-skill rules"
  / "Worktree scope" / "Public skills marker block" / "Honest framing"
  — wszystko `static` / `from skills.compiled.json` / `from .sage/
  config.yaml profile`. **Nigdzie z `.sage/constitution.md`**.
- ADR-5 §"User additions to AGENTS.md" pozwala użytkownikowi dopisać
  cokolwiek poniżej `## --- USER ADDITIONS BELOW ---`. To jest
  **alternatywa** dla constitution merge — ale nie jest to ten sam
  mechanizm. User dopisuje rules per-AGENTS.md, nie per-`constitution.md`
  z preset.

**Impact:** Użytkownik na Codex traci capability rozszerzania
konstytucji presetem (`startup`, `enterprise`, `opensource`) i własnymi
zasadami **z osobnego pliku** który jest wspólny dla wielu portów.
Claude direct deploy ma to; Codex by tego nie miał.

**Suggested action:** UDOKUMENTUJ albo WYRÓWNAJ. Albo:
- (a) ADR (nowy lub rozszerzenie ADR-5) "constitution merge on Codex":
  `.sage/constitution.md` + `core/constitution/presets/<X>.md` →
  merge → AGENTS.md "constitution" block. Z ten sam mechanizm Python3/sed
  fallback co Claude. **Z tej drogi idzie cross-port shared
  capability.**
- (b) ADR uzasadniający rejection: "Codex konsumuje constitution przez
  user additions zone w AGENTS.md, nie przez merge". Wtedy w `bin/sage
  init` migracja: jeśli user ma `.sage/constitution.md` → wlej go do
  user-additions zone i ostrzeż że dla Codex to single-source.

Brak ADR = nieświadomy drift.

---

### Capability 3: `cap-apply-prefix` (mapa §3.3)

**Claude robi to przez:** Jeśli `command_prefix: true` w
`.sage/config.yaml` → prefiksuje wszystkie `/cmd` jako `/sage:cmd`
w CLAUDE.md (sed) i w nazwach plików. **Tylko direct deploy.** Plugin
nie prefiksuje.

**ADR Codex zakłada:** Cross-port-survey §3 mówi że Codex używa
"skill mentions, not slash commands" → "N/A". ADR-5 §"Public skills
marker block" pokazuje listę `$build`, `$fix`, `$architect`, etc. —
**hard-coded prefix `$`**.

**Verdict:** DOCUMENTED DIVERGENCE z **jednym otwartym pytaniem**.

**Detail:**
- Codex po deprecacji slash commands 2026-01-22 (per ADR-4 § Context)
  nie ma slash commands jako konceptu. Brief V2 wprost: "no slash
  commands; skill mentions `$skillname` instead". OK.
- `$` jako prefix (zamiast `/sage:`) jest hard-coded w ADR-5 i ADR-4.
  Nie ma toggle "namespace prefix true/false" odpowiednika
  `command_prefix` w Claude.
- **Otwarte pytanie:** Codex ma collision risk innym sposobem —
  wszystkie skille są w global namespace `~/.codex/...` plus per-project
  `.agents/skills/`. Jeśli inny projekt też ma skill nazwany `build`,
  jest collision. **Mapa §6.4** mówi że Claude rozwiązał to przez
  `command_prefix: true` na `/sage:build`. Codex nie ma analogu.

**Impact:** Niski w v1 (sage-selfhost solo dev), ale dla v2 downstream
(brief V4) — jeśli ktoś sklonuje framework do projektu który już ma
swój skill `build`, mamy collision. ADR-4 §3.2 wspomina
`mention_aliases: removed entirely` — user explicitly nigdy nie chce
aliasów. Ale to **nie rozwiązuje** collision name w globalnym
namespace.

**Suggested action:** UDOKUMENTUJ. Krótki wpis w spec.md albo ADR-4
§"Cross-platform consistency": "Codex skill names live in global
namespace; collision with non-Sage skills jest user's responsibility
to resolve. v2 candidate: namespace prefix `sage_build` jeśli pattern
emerges". Bez tego — agent przyszły sklonujący framework może być
zaskoczony że nazwy skilli ze skill manifest to global names.

---

### Capability 4: `cap-inject-preamble` (mapa §3.4) ⚠️ KRYTYCZNE

**Claude robi to przez:** Per-workflow compliance preamble (np.
"MEMORY FIRST", "spec.md MUST EXIST", "[A] = REVIEW = run sub-agent")
inline w bash `case` w `generate-claude-code.sh` linie ~510-760.
Plugin generator parsuje go awk-iem → tight coupling, fragile.
Mapa §3.4 nazywa to "JEDNYM z głównych pain pointów portu Claude".

**ADR Codex zakłada:** ADR-6 (preamble extraction). Ekstrakcja
preambles do `core/preambles/<workflow>.md` z YAML frontmatter
`teaser: |...` (≤300 chars dla discovery) + markdown body (full
rules, lazy-loaded). Wszystkie trzy generatory (Claude direct,
Claude plugin, Codex) czytają ten sam plik z `sed`. Eliminacja
awk parsing.

**Verdict:** PARITY (z poprawą).

**Detail:**
- Codex **świadomie naprawia pain point Claude'a** (ADR-6 § Context
  cytuje mapę Claude §3.4, §6.2). To jest cross-port refactor
  uzasadniony C5 brief'u.
- Migration plan ADR-6 §6 jest ostrożny: byte-equivalent generator
  output na Claude side. Czyli **Claude direct + Claude plugin nie
  tracą żadnego zachowania**, tylko zmienia się skąd preamble jest
  czytany (z bash case → z `core/preambles/<wf>.md`).
- Trzeci konsument (Codex) używa teaser layer dla 8000-char cap, full
  body dla skill body. To jest dodatkowa funkcja, nie rozjechanie.
- Boundary test (ADR-6 Q4) jest wprost zgodny z konstytucją Sage
  (CLAUDE.md "Cross-skill rules" vs per-workflow gates).

**Impact:** Pozytywny dla wszystkich portów. To jest **win-win**
ekstrakcji.

**Suggested action:** ZOSTAW. Best practice. Jedyne ostrzeżenie
do spec.md: ADR-6 §Step 6 "byte-equivalent generator output" jest
**hard regression test** — implementacja MUSI to przejść na Claude
przed wszystkim innym, inaczej rejected redesign cycle pattern się
powtarza.

---

### Capability 5: `cap-wire-hooks` (mapa §3.5)

**Claude robi to przez:**
- Direct: `.claude/settings.local.json` z `SessionStart` (matcher:
  `startup|resume|clear|compact`) → `bash .claude/hooks/sage-session-init.sh`.
- Plugin: `hooks/hooks.json` z `SessionStart` (bez matcher) +
  `PostToolUse` (matcher: `Write|Edit`) → `sage-verify.sh`.
- Atomic write (mktemp + mv).
- Asymmetria: `PostToolUse` tylko w pluginie.

**ADR Codex zakłada:** ADR-5 §`Stop` + ADR-1 + ADR-2 W2 + ADR-3.
Cztery hooki w v1: `SessionStart`, `UserPromptSubmit`, `PreToolUse(apply_patch)`,
`Stop`. Wszystkie thin bash shims → MCP. `[features].codex_hooks = true`
jako single key activation (decision-codex-hook-activation.md).
Trust gate via `[projects."<abs>"].trust_level = "trusted"`.
Idempotent merge logic z framework hashes (decision-codex-hook-activation.md
§Identity rule).

**Verdict:** DOCUMENTED DIVERGENCE.

**Detail:**
- Codex używa **innego zestawu eventów hookowych** niż Claude.
  Claude (direct + plugin łącznie) ma {`SessionStart`, `PostToolUse`}.
  Codex v1 ma {`SessionStart`, `UserPromptSubmit`, `PreToolUse(apply_patch)`,
  `Stop`}. **Brak `PostToolUse` w Codex v1.** ADR-5 wprost defers
  `PostToolUse` do v2 z uzasadnieniem.
- Codex używa **PreToolUse** (przed mutation) gdzie Claude używa
  **PostToolUse** (po mutation). Mapa §6.3 mówi że to jest **lepszy
  anchor** dla Codex (research base — mutation-time enforcement).
  Świadoma decyzja, w briefie V2 mechanism divergence.
- Codex dodaje **`UserPromptSubmit`** (UPS-token) i **`Stop`** (turn
  audit) których Claude w ogóle nie ma. To są nowe capabilities
  uzasadnione przez:
  - UPS: ADR-2 W2 — approval token (Claude nie ma, bo Claude jest
    synchroniczny human+agent w 1 turn — porównaj cross-port-survey §4 Q5).
  - Stop: ADR-7 — turn audit (Claude nie ma, bo Claude w direct deploy
    nie ma post-write verify).
- Codex aktywacja przez **JEDEN klucz** (`[features].codex_hooks`)
  + osobny trust gate (per ADR-5 FM-2). Claude direct deploy aktywuje
  hooki przez sam fakt obecności `settings.local.json`. Plugin
  aktywuje się przez instalację marketplace. Różne mechanizmy ale
  oba "zero config dla użytkownika".
- **Hook activation merge logic** (decision-codex-hook-activation.md
  §Identity rule + §Known framework hashes) jest znacznie bardziej
  rozwinięty niż w Claude (Claude robi atomic write całego
  settings.local.json, brak shadowed file detection). To **lepsze
  rozwiązanie** wynikające z lessons learned (cross-repo discipline,
  M0-M3 cycle).

**Impact:** Świadomie inny zestaw mechanizmów dla osiągnięcia tej
samej outcome (workflow guard before mutation, context injection,
audit trail). Brief V2 to wprost autoryzuje.

**Suggested action:** ZOSTAW. Wszystko udokumentowane. Jedna uwaga:
**brief brak PostToolUse w Codex v1 to SAME asymmetry that Claude
plugin has** (Claude direct nie ma PostToolUse, plugin ma). Mapa §3.7
nazywa tę asymetrię "LUKA". Codex robi pre-mutation gating zamiast
post-mutation, **ale** plugin Claude'a ma post-mutation verify
ogólny (orchestrates spec-check, hallucination-check, visual-gate).
Codex `PreToolUse(apply_patch)` ogranicza do mutation predicate (P1-P4
ADR-1) i **nie sprawdza** hallucination references ani visual gate.
To jest **subtelna luka** — Codex może dopuścić write który ma
hallucinated reference do nieistniejącego pliku, podczas gdy plugin
Claude'a by to złapał. Pytanie do spec.md: czy hallucination-check
jest wykonywany w Codex `Stop` hook (audit) czy nie wcale? ADR-7 § C1-C7
**nie ma** hallucination check. Możliwy gap.

---

### Capability 6: `cap-context-injection` (mapa §3.6)

**Claude robi to przez:** Runtime behavior `sage-session-init.sh`.
Czyta `.sage/work/*/` frontmatter (title, status, phase),
`.sage/docs/` (count), ostatnie 3 wpisy `### ` z `decisions.md`.
Wypluwa structured markdown na stdout — Claude wraps w
`<system-reminder>`. Bash-only, zero deps, timeout 10s w pluginie.

**ADR Codex zakłada:** ADR-5 §`SessionStart` —
`runtime/platforms/codex/hooks/session-init.sh`. Action sequence:
1. Verify `[features].codex_hooks = true` (warn if not).
2. Verify project trust state (warn if not).
3. Read `.sage/work/*/manifest.md` frontmatter (status: in-progress
   or paused), emit summary block.
4. Read latest 3 `### ` entries z `.sage/decisions.md`. Emit compact list.
5. Output to stdout — Codex wraps w system-reminder equivalent.
6. Replaces Claude port's `sage-session-init.sh` (mapa §3.6 — same
   logical capability, platform-different surface).

**Verdict:** PARITY.

**Detail:**
- Identyczna logika.
- Codex dodaje **dwa preflight checks** (codex_hooks flag + trust
  state). Claude tego nie potrzebuje bo jego hooki nie są gated
  przez trust_level. To jest **honest signaling** wymagany przez
  Codex'a strukturę (research base §4.5 silent-failure mode).
- Codex **NIE czyta** `.sage/docs/` count (Claude czyta, mapa §3.6).
  **Mała różnica.** Drobny drift — jeśli intencja była parytet pełny,
  Codex też powinien czytać count. Jeśli intencja to "lighter
  context", powinno być w ADR.
- ADR-5 §`SessionStart` step 5 "Codex wraps it in a system-reminder
  equivalent" — to terminologia. Codex w rzeczywistości może
  wstrzyknąć to inaczej (research base §4.5 mówi że stdout z hook
  ląduje w session-prelude). Implementacja to zweryfikuje.

**Impact:** Niski. Brak count `.sage/docs/` to drobne kosmetyka.

**Suggested action:** WYRÓWNAJ. Drobny edit w ADR-5 §`SessionStart`
action sequence: dodać krok "3a. Read `.sage/docs/` count, include
in summary." Jeśli świadomie usunięte — uzasadnij w ADR że
`.sage/docs/` count nie jest sygnałem dla agenta na starcie sesji.

---

### Capability 7: `cap-post-write-verify` (mapa §3.7) ⚠️ LUKA

**Claude robi to przez:** Plugin only — `sage-verify.sh
${CLAUDE_PROJECT_DIR}` po Write/Edit. Verify orchestruje:
`sage-spec-check.sh` (spec exists), `sage-hallucination-check.sh`
(claimed-but-missing refs), `sage-visual-gate.sh` (visual review).
Timeout 30s. **Egzekwuje Rule 5: Verify Before Claiming Done na
poziomie platformy.** Direct deploy NIE ma post-write verify.

**ADR Codex zakłada:** **NIE MA `PostToolUse` w v1.** Zamiast tego:
- Pre-mutation: `PreToolUse(apply_patch)` → `sage_validate_mutation`
  (P1-P4 z ADR-1: active initiative + mutation target in scope +
  workflow gate satisfied + approval proof intact).
- Turn-end: `Stop` → `sage_audit_turn` (ADR-7 7 checks: stale token,
  forge, pending gate, tier-1 self-promotion, --no-verify,
  dead-validator, bypass-write).
- Commit-time: L5 pre-commit (ADR-1 trade-offs).

**Verdict:** DOCUMENTED DIVERGENCE z **jedną luką**.

**Detail:**
- Codex **świadomie wybiera pre-mutation** zamiast post-mutation jako
  primary anchor. Brief V2 + research base §4.5. ADR-1 §Cross-port
  truth: "The Codex port is the first Sage port to implement
  deterministic pre-mutation gating".
- ADR-1 P1-P4 obejmuje **inne checki** niż Claude'owy verify:
  - P1: active initiative — Claude tego NIE sprawdza.
  - P2: mutation scope — Claude tego NIE sprawdza explicit.
  - P3: workflow gate — Claude robi to via `sage-spec-check.sh`. **Parytet.**
  - P4: approval proof intact — Claude tego NIE ma w post-write
    verify (Claude trust uses file existence, cross-port-survey §4 Q5).
- **LUKA: hallucination-check + visual-gate NIE są w Codex.**
  - `sage-hallucination-check.sh` (Claude plugin) sprawdza czy
    artifact references istniejące pliki. To jest specific check
    nie pokryty przez ADR-1 P1-P4 ani ADR-7 audit checks.
  - `sage-visual-gate.sh` (Claude plugin) — visual review. Też nie
    pokryty. Brief Q7 outcome harness include "build with typos" —
    ale to nie to samo co visual-gate.
- ADR-7 C1-C7 audit checks **nie obejmują** ani hallucination ani
  visual. To są **inne klasy weryfikacji** niż gate predicate.
- Mapa §3.7 wprost mówi: "egzekwuje Rule 5: Verify Before Claiming
  Done na poziomie platformy". Codex egzekwuje przez **outcome
  harness** (ADR-8) — ale to jest **integration test**, nie runtime
  verify. Outcome harness nie odpala się per-write.

**Impact:** Codex w runtime może dopuścić mutation która referencuje
nieistniejący plik (hallucination), bo `sage_validate_mutation`
patrzy tylko na existence + status + approval proof. Plugin Claude'a
by to złapał.

**Suggested action:** UDOKUMENTUJ DECYZJĘ albo WYRÓWNAJ:
- (a) ADR amendment do ADR-1 P5 (lub nowy ADR): "hallucination check
  on Codex". Może to być w MCP `sage_validate_mutation` jako
  dodatkowy check przed allow. Albo w Stop hook (`sage_audit_turn`)
  jako C8.
- (b) Świadome odrzucenie: "Codex zostawia hallucination check
  użytkownikowi". Wtedy ADR uzasadnia: "hallucination jest
  niskoprawdopodobne na pre-mutation poziomie, bo agent Codex pisze
  spec → plan → kod, więc references są weryfikowane na review-time
  przez user'a, nie na write-time".

Z mapy Claude'a wynika że hallucination check to ważny drawer'cik.
Brak ADR = drift, nie świadoma decyzja.

---

### Capability 8: `cap-bootstrap-state` (mapa §3.8)

**Claude robi to przez:** Idempotentne tworzenie `.sage/`. Jeśli brak:
mkdir work/, docs/, write decisions.md (init line) + conventions.md.
**Zawsze:** copy `core/gates/scripts/*.sh` → `.sage/gates/scripts/`
(chmod +x), copy `core/gates/_config/gate-modes.yaml` →
`.sage/gates/`. Opcjonalnie (`deploy_loader_stubs: true`): write
`.claude/skills/<prefix><skill>/SKILL.md` jako redirector.

**ADR Codex zakłada:** **NIC EXPLICIT.**

Najbliższe: ADR-3 D2 step 5 "write a launch shim at `~/.sage/bin/
sage-mcp-server`", ADR-3 D2 step 4 "fail `sage init` (do not
silently skip)", ADR-5 §"Migration plan" Step 5 "sage init flow".
Brief §Key Flow step 1: "User runs `sage init` in a project."

**Verdict:** **BEHAVIORAL DRIFT (nieświadomy).**

**Detail:**
- Cross-port-survey §1.3 (Antigravity) §3 (Generic) wprost: bootstrap
  state copies `core/gates/scripts/*.sh` → `.sage/gates/scripts/`,
  chmod +x. Cross-port-survey §5 surprise 4: "Bootstrap state
  exists identically across Claude, Codex, Antigravity but Generic.
  Claude, Codex, and Antigravity all copy `core/gates/scripts/*.sh`
  and `gate-modes.yaml` unchanged."
- Ale ADRy Codex **nie wspominają** tego mechanizmu. Sage'owa fraza
  "L5 pre-commit" (ADR-1 + ADR-7) odwołuje się do **Sage gate scripts**
  ale gdzie one są na Codex? `.sage/gates/scripts/` per Claude pattern
  — ale ADR Codex tego nie deklaruje wprost.
- ADR-9 §S4 "writers manifest enforcement" — `runtime/platforms/codex/
  audit/sage-writers.yaml`. To jest **inny artifact** niż
  `.sage/gates/scripts/`. Drift nazewnictwa.
- ADR-7 §C5 mówi "L5 pre-commit hook writes `.sage/.precommit.log`".
  L5 pre-commit hook **pochodzi z core/gates/scripts/**. Ale ADR nie
  mówi gdzie ten hook fizycznie jest na Codex.

**Impact:** Wysokie ryzyko gap'u w implementacji. Jeśli `bin/sage init`
na Codex nie skopiuje `core/gates/scripts/*.sh` do `.sage/gates/scripts/`:
- ADR-7 C5 (`--no-verify` detection) nie zadziała bo L5 nie istnieje.
- ADR-1 trade-offs L5 backstop nie działa.
- Workflow gate predicates używają tych skryptów per cross-port survey.

**Suggested action:** UDOKUMENTUJ EXPLICITNIE. Dodać do ADR-9 albo
nowego mini-ADR'u "ADR — Codex bootstrap state":
- `bin/sage init` na Codex MUSI:
  - mkdir `.sage/work/`, `.sage/docs/`, `.sage/.cache/`
  - touch `.sage/decisions.md` + `.sage/conventions.md`
  - copy `core/gates/scripts/*.sh` → `.sage/gates/scripts/` (chmod +x)
  - copy `core/gates/_config/gate-modes.yaml` → `.sage/gates/`
  - install MCP server shim per ADR-3 D2 (this jest udokumentowane)
  - install hook scripts per ADR-5 (this jest udokumentowane)
  - install pre-commit hook per L5 (THIS IS NOT DOCUMENTED)

Bez tego — outcome harness odpali się i nie złapie braku, bo prompty
testowe nie odwołują się eksplicit do `--no-verify` detection.

---

## Cross-cutting patterns

### Pattern 1: "Claude polega na bash, Codex polega na MCP"

Codex konsekwentnie przesuwa logikę z bash do Pythona MCP. To jest
świadome:
- Claude mutation guard: nie ma (PostToolUse plugin tylko verify).
- Codex mutation guard: bash shim → `sage_validate_mutation` MCP
  (P1-P4 predicates). Logika w Pythonie (ADR-3 D4 layout).
- Claude approval: implicit (file existence).
- Codex approval: bash UPS shim → `.approval-pending` token →
  `sage_record_approval` MCP. Logika w Pythonie.
- Claude turn audit: nie ma.
- Codex turn audit: bash Stop shim → `sage_audit_turn` MCP. 7 checks
  w Pythonie.

**Czy ten kompromis jest świadomy?** TAK — brief C3 ("Bash + Python
+ whatever the task needs"), ADR-3 D1 ("Sage's existing helpers...
are Python. Stack consistency"), ADR-5 §"Why thin bash shims, not
inline hook logic" (3 powody: auditability, single source of truth,
cross-platform).

**Konsekwencja dla parytetu:** Codex jest **zależny** od MCP up.
ADR-3 D6 + ADR-3 §Required = true to robi explicit. Claude direct
deploy działa **bez** MCP (zero deps). Codex bez MCP **nie zaczyna
sesji**. Brief G4 to autoryzuje.

Gdyby Codex MCP padło dla użytkownika (np. instalacja `uv` failed,
Python upgrade w środku, port conflict), użytkownik nie zaczyna
sesji. Claude w analogicznej sytuacji (np. settings.local.json
malformed) **nadal otwiera sesję** — tylko hooki nie odpalają.
Codex jest **strictly less degradable**. Brief V3 honest framing
to autoryzuje, ale UX implications dla junior dev są realne (brief
V4 user = Alex/junior).

### Pattern 2: "Codex egzekwuje na fail-closed, Claude na trust"

Mapa §3.7: Claude'owy verify fires na **specific event** (Write/Edit)
i jeśli timeout 30s — Claude może przejść dalej (timeout default
behavior unspecified w mapie ale plugin docs sugerują że timeout
to soft-deny).

Codex `PreToolUse(apply_patch)` per ADR-1 fail-closed — deny default,
allow tylko gdy MCP odpowie allow. Per ADR-3 D6 — jeśli MCP padło,
mutation deny przez `Transport closed`. Per PoC C1 T3 zweryfikowane.

**Konsekwencja:** Codex jest **bardziej restrictive** w runtime niż
Claude. Może to być pożądane (V3 strict guarantee), albo frustrating
dla junior dev który nie wie czemu apply_patch fails.

Mitygacja przez `sage doctor --strict` (ADR-9 D2) i clear error
messages ADR-1 §"Cold-start" — uzasadnione.

### Pattern 3: "Codex ma więcej audytu niż Claude"

ADR-7 (Stop hook scope) wprowadza **siedem** check'ów audytowych:
stale_token, forge_token, pending_gate, tier1_self_promotion,
no_verify_commit, dead_validator, bypass_write. Plus dwa nowe artifaktu
(`.ups-hook.log`, `.session-mutations.log`) i jeden modyfikowany
(`.precommit.log`).

Claude **nie ma analogu**. Plugin verify orchestruje 3 gate scripts
ale to jest **gate**, nie audit. Audit jest concept Codex-only,
**świadomie wprowadzony** przez ADR-7 i wymagany przez brief V3
honest framing (forge framing).

**Czy to jest świadoma asymetria?** TAK. ADR-7 § Why this matters
+ § Detection vs prevention to wyjaśnia.

**Czy Claude powinien mieć analog?** Out of scope review, ale
warto odnotować dla v2 cross-port consistency. Brief C4
"modify-with-care for Claude port" — nie w v1.

---

## Recommended actions (priority order)

### P1 — Krytyczne (przed spec.md)

1. **Napisać ADR (lub mini-rozdział w spec.md) "Codex bootstrap
   state"** — explicit declaracja co `bin/sage init` na Codex robi,
   włącznie z `core/gates/scripts/` copy + L5 pre-commit hook
   install. Bez tego ADR-7 C5 + ADR-1 L5 backstop są wishful
   thinking. **(MISSING CAPABILITY z mapy §3.8.)**

2. **Decyzja o hallucination-check i visual-gate na Codex.** Albo:
   (a) ADR amendment ADR-1 P5 dodający te checki w
   `sage_validate_mutation` lub `sage_audit_turn`, albo
   (b) ADR explicit rejection z uzasadnieniem. Bez tego **luka
   funkcjonalna** vs Claude plugin verify. **(BEHAVIORAL DRIFT
   z capability §3.7.)**

3. **Decyzja o constitution merge na Codex.** Albo:
   (a) ADR rozszerzenie ADR-5 dodający `.sage/constitution.md` +
   `core/constitution/presets/<X>.md` merge → AGENTS.md "constitution"
   block.
   (b) ADR explicit rejection: "Codex konsumuje constitution przez
   user additions zone w AGENTS.md" + migracja w `bin/sage init` dla
   istniejących projektów z `.sage/constitution.md`.
   **(BEHAVIORAL DRIFT z capability §3.2.)**

### P2 — Ważne (do zaadresowania w spec.md)

4. **Napisać ADR "Codex distribution target (single)"** — explicit
   że Codex ma 1 ścieżkę dystrybucji (project-local), nie 2 jak
   Claude. To jest świadoma decyzja brief'u ale nie jest spisana
   jako ADR i robi się w niej zgubienie czytelnika.

5. **Drobny edit w ADR-5 §`SessionStart` action sequence** —
   dodać krok czytania `.sage/docs/` count, parytet z mapą §3.6.
   Albo udokumentować świadome usunięcie.

6. **Zdefiniować skill namespace strategy on Codex** w spec.md albo
   dodać sekcję do ADR-4 §"Cross-platform consistency" — jak działa
   collision risk w globalnym namespace `~/.codex/...`. v1 może
   być "user resolves manually", ale to musi być powiedziane.

### P3 — Cleanup (przed v1 cutover)

7. **Sprawdzić wszystkie ADRy pod kątem absentnej referencji do
   `core/gates/scripts/` lub `.sage/gates/scripts/`** — jeśli L5
   pre-commit jest tam, to ścieżka MUSI być explicit.

8. **Cross-link mapa §3.X → ADR Codex** — w manifest.md cycle Codex
   port rewrite dodać tabelkę "Claude capability → Codex ADR" żeby
   przyszły reviewer szybko widział pokrycie. Z tej review wynika
   że pokrycie nie jest pełne (kilka świadomych deferowań do v2 +
   2 driftowe luki).

---

## Notatka końcowa

Ta review jest cross-checkiem behawioralnej zgodności. **Nie ocenia**
czy Codex robi rzeczy lepiej, ani nie kwestionuje świadomych decyzji
brief'u (V2 outcome parity / mechanism divergence). Z 17 capabilities
+ pokryć: 7 jest świadomie inaczej (DOCUMENTED DIVERGENCE), 4 to
PARITY, 3 to nazewnictwo, 1 missing, 2 driftowe.

Driftowych jest **dwa**: cap-bootstrap-state (gate scripts) i
cap-post-write-verify (hallucination + visual). Plus jeden missing
(constitution merge). To jest do zaadresowania **przed spec.md**.

Pozostałe (terminology, distribution target single, skill namespace)
są do dodania w spec.md jako sekcje wyjaśniające.

Mapa Claude'a §6 (Insights) była rzetelna; wszystkie tezy z tej
sekcji znajdują odbicie w ADRach (preamble extraction, mutation
anchor, single distribution path, prefix N/A na Codex). To
zwiększa confidence że Codex design **rozumie** co Claude robi —
luki są w detalach implementacyjnych, nie w fundamental
architecture.
