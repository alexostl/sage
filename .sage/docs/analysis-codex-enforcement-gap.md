---
title: "Codex Enforcement Gap Analysis"
type: analysis
status: completed
date: 2026-04-23
scope: custom
artifact_prefix: analysis
related:
  - runtime/platforms/codex/setup/generate-codex.sh
  - runtime/platforms/claude-code/setup/generate-claude-code.sh
  - runtime/platforms/codex/README.md
  - runtime/platforms/codex/HOOKS.md
---

# Codex Enforcement Gap Analysis

**Question.** Dlaczego agent na porcie Codexa traktuje Sage framework jako
inspirację, podczas gdy na Claude Code idzie restrykcyjnie według workflow?

**Methodology.** Side-by-side porównanie generatorów platform (`generate-claude-code.sh`
vs `generate-codex.sh`), plików instrukcji (`CLAUDE.md` vs `AGENTS.md`),
mechanizmów iniekcji reguł (preamble w slash commandach vs workflow skills),
hooków SessionStart i tool gating.

**Verdict.** Gap jest realny, systemowy i zlokalizowany w dwóch miejscach:
(1) rozmiar i ton Process Constitution w `AGENTS.md`, (2) brak per-workflow
PREAMBLE injection przy aktywacji workflow skilla na Codexie. Trzecim czynnikiem
wzmacniającym jest opt-in/minimalny status hooków na Codexie.

---

## Findings

### Critical

#### C1. Brak PREAMBLE injection dla workflow skills na Codexie

**Evidence.** `runtime/platforms/claude-code/setup/generate-claude-code.sh:509-751`
ma `case "$basename_wf"` ze zdefiniowanym PREAMBLE dla każdego workflow
(`build`, `fix`, `architect`, …). Ten PREAMBLE prepends 10–15 reguł na górę
każdego pliku `.claude/commands/[cmd].md`, np. dla `build`:

- `MEMORY FIRST: Before writing spec, plan, or starting implementation, search sage-memory … This is MANDATORY, not optional.`
- `Standard+ scope: spec.md MUST EXIST at .sage/work/ before implementing. "Design is clear" is NOT a spec. "We discussed this" is NOT a spec.`
- `[A] = REVIEW: When user picks [A] at spec or plan checkpoint, you MUST run auto-review sub-agent BEFORE proceeding.`
- `Blocked rationalizations: "The spec is straightforward" — [A] means review. Period.`
- `Verify: PASTE actual test output before claiming done — no summaries`

`runtime/platforms/codex/setup/generate-codex.sh:269-304` generuje skills
przez:

```
sed '/^---$/,/^---$/d' "$wf_file"
```

czyli **strippuje frontmatter i dumpuje raw `workflow.md`**. Żaden PREAMBLE nie
jest wstrzykiwany. `SKILL.md` dostaje tylko jednolinijkowy nagłówek
`Codex-native workflow skill for Sage.`

**Impact.** Agent Codex czytając `.agents/skills/build/SKILL.md` dostaje
workflow jako procedurę (kroki 1→N), ale nie dostaje adversarial wrappera:
MANDATORY memory search, FILE CHECKS, blocked rationalizations, [A]=REVIEW
mechanics. Dokładnie to jest różnica między "workflow jako inspiracja" i
"workflow jako non-negotiable gate".

**Severity rationale.** Critical, bo jest to **single biggest delta** między
platformami na tej samej warstwie (workflow activation), w tym samym generatorze.

**Location.**
- Claude: `runtime/platforms/claude-code/setup/generate-claude-code.sh:509-751`
  (PREAMBLE definicje) + `951-963` (injection)
- Codex: `runtime/platforms/codex/setup/generate-codex.sh:280-299`
  (brak injection)

**Recommendation.** Zreplikować mechanizm PREAMBLE w `generate-codex.sh`. Te
same treści, przepisane na Codex terminologię (`/sage:build` → `$build`,
`Task tool` → `Codex subagent`, `.claude/commands/` → `.agents/skills/`). To
nie jest copy-paste — niektóre reguły Claude-specyfic (np. "Task tool might
not work") trzeba zmapować na equivalent mechanizm Codexa.

---

#### C2. AGENTS.md Process Constitution jest cieniem CLAUDE.md

**Evidence.** Raw line count: `CLAUDE.md` 352 linie, `AGENTS.md` 165 linii.
To nie jest jednak tylko objętość — brakuje całych sekcji enforcement:

| Element | CLAUDE.md | AGENTS.md |
|---------|-----------|-----------|
| Rule 0 (routing) | 3-layer chain + tier classification + 4 worked examples | 1 routing table + "ambiguous → sage" |
| Rule 1A (Memory First) | Full section, MANDATORY, 2-search minimum, MCP parameter types | **ABSENT** |
| Workflow Gates section | 40 linii: Build FILE CHECKS + "Do NOT rationalize skipping" list + Fix scope ladder + Architect elicitation rounds | **ABSENT** |
| Rule 5 self-check | FILE CHECKS (nie self-assessment): "does spec.md exist? If no → go back" | 3 ogólne punkty ("run tests/checks") |
| Rule 6 (Capture Corrections) | Storage target specifics (`sage_memory_store` vs platform native memory) | **ABSENT** (zostało zgenerowane jako Rule 6 "Keep State Shared" — inna reguła) |
| Rule 7 (Decisions prepend) | Pełna reguła z archiwacją | **ABSENT** |
| Compliance signals | Każda reguła ma "**Compliance:** [observable signal]" | **ABSENT** |
| Tier classification | Tier 1/2/3 + "Bias toward Standard scope" | **ABSENT** |
| Interaction Zones | Zone 1-4 explicit footers | **ABSENT** |
| Learning Triggers | 6 trigger types z prescribed format | **ABSENT** |
| Routing examples | 4 konkretne przykłady | **ABSENT** |
| Commands table | 14 komend z opisami | **ABSENT** |

**Specific comparison — Build rule.** AGENTS.md Rule 3 w całości:

```
For Standard+ build work, both files must exist before implementation:
- .sage/work/<initiative>/spec.md
- .sage/work/<initiative>/plan.md
If either file is missing, create it first.
```

5 linii, neutralny ton. CLAUDE.md odpowiednik (`Workflow Gates → Build`):

```
BEFORE implementing, verify BOTH files exist on disk:
  .sage/work/[initiative]/spec.md — with status: completed
  .sage/work/[initiative]/plan.md — with status: completed
If EITHER file is missing → create it first. No exceptions.

Do NOT rationalize skipping:
- "The design is clear from previous discussion" → NOT a spec file
- "The user described what they want" → NOT a spec file
- "This is straightforward" → if Standard scope, spec required
- "Just build it" → write a minimal 5-line spec, get [A]/[R]
```

plus Gate sequence (1→4). Rozmiar (5 linii vs 40 linii), ton (neutralny vs
imperatywny), coverage (brak adversarial anty-rationalization listy).

**Impact.** Agent na Codexie czyta AGENTS.md na starcie sesji, ale dostaje
**rulebook**, nie **constitution**. Brak compliance signals (obserwowalny
sygnał czy reguła została zastosowana) → agent nie ma how-to-self-check.
Brak Tier classification → "Bias toward Standard scope" nie istnieje →
małe taski pomijają proces. Brak "Do NOT rationalize skipping" → każda
wymówka w głowie agenta zostaje niekontrargumentowana.

**Severity rationale.** Critical, bo Process Constitution jest **always-on
layer**. Ta warstwa MA być identyczna pod względem mocy rules między
platformami; tutaj pod względem mocy jest asymetryczna ~2:1.

**Location.** `runtime/platforms/codex/setup/generate-codex.sh:31-197`
(heredoc `AGENTSEOF`).

**Recommendation.** Przepisać `AGENTS.md` heredoc, zaciągając wszystkie
sekcje z `CLAUDE.md` jako źródło prawdy. Dla każdej sekcji zastosować
podstawienia:
- `/sage` → `$sage` (lub ewentualnie obie formy)
- `.claude/commands/` → `.agents/skills/`
- `Task tool` → `fresh Codex subagent/agent`
- Zachować wszystkie 7+ reguł, Rule 1A, Workflow Gates, Tier, Compliance,
  Interaction Zones, Learning Triggers, Routing examples, Commands table.

---

### Major

#### M1. SessionStart hook jest opt-in i minimalny na Codexie

**Evidence.** Claude Code:
- Hook generowany automatycznie przez `generate-claude-code.sh:1069-1113`
  do `.claude/hooks/sage-session-init.sh`
- Wired w `settings.local.json` przez ten sam generator
- Fires on `startup|resume|clear|compact`
- Output: pełny kontekst (aktywne inicjatywy z frontmatterem,
  in-progress task, licznik docs, 3 ostatnie decyzje)

Codex:
- `generate-codex.sh` **nie wrapuje żadnego hooka**
- Hook (`session-start.sh`) dostępny tylko w `runtime/platforms/codex/hooks/`
  jako **starter pack** do ręcznego kopiowania
- Wymaga opt-in: `[features].codex_hooks = true` w `.codex/config.toml`
- Fires tylko na `startup|resume`
- Output: jednolinijkowy reminder (`Sage workspace detected. Before
  substantial work, read .sage/work/ for active initiatives…`)

`HOOKS.md:1-14` explicit:
> Codex hooks are currently experimental. Treat this starter pack as an
> opt-in native extension point, not as full Claude-style lifecycle
> enforcement.

**Impact.** Default Codex user dostaje **zero context injection** na
starcie sesji. Rule 1 (State First) traci forcing function —
zależy od agenta że przeczyta `.sage/` bez reminderu. Nawet gdy user
opt-inuje hook, treść to jedno zdanie vs rich context.

**Severity rationale.** Major, nie Critical, bo to jest wzmacniacz
problemu C2 (słaby AGENTS.md) a nie sam rdzeń. Gdyby AGENTS.md był
tak mocny jak CLAUDE.md, brak hooka byłby znośny.

**Location.**
- `runtime/platforms/codex/setup/generate-codex.sh` (brak sekcji hook)
- `runtime/platforms/codex/hooks/session-start.sh:11-25`
- `runtime/platforms/codex/HOOKS.md:1-14`

**Recommendation.** Dwa sub-warianty:
1. **Minimalny:** Zwiększyć treść `session-start.sh` do rich context
   (active work + in-progress + recent decisions), identycznej treści
   jak `claude-code/hooks/sage-session-init.sh`. Zostawić jako opt-in.
2. **Pełny:** Dodać do `generate-codex.sh` automatyczne instalowanie
   hooka do `.codex/hooks.json` + włączanie `[features].codex_hooks = true`
   w `.codex/config.toml`, jeśli user nie wyłączył explicite. Zachować
   ścieżkę "turn off" jeśli user nie chce.

---

#### M2. Brak per-workflow tool gating / PreToolUse enforcement

**Evidence.** Claude Code PreToolUse może blokować narzędzia na podstawie
matchera i stanu workflow (file checks, gate sequence). Codex PreToolUse
**tylko** dla Bash (`HOOKS.md: "only watches Bash commands"`). Obecny
starter `pre-bash.sh` blokuje tylko 4 destructive patterny (`git reset
--hard`, `git clean -fd`, `git clean -xfd`, `rm -rf /`). Brak mechanizmu
"nie pozwól użyć Edit/Write dopóki spec.md nie istnieje".

**Impact.** FILE CHECKS z C1 nie mają deterministic enforcement — bazują
na prompt compliance, nie na tool gating. Agent który zignoruje prompta
może edytować pliki bez spec.md i nic go nie zatrzyma.

**Severity rationale.** Major. Nie Critical bo nawet Claude nie ma
bulletproof file-check gatingu przez hooki — tam też prompt robi robotę.
Ale na Codexie nawet partial enforcement jest słabszy.

**Recommendation.** Długofalowo: ship deterministic gate script
(`.sage/gates/scripts/check-spec-plan-exist.sh`) który PreToolUse może
wywołać przed `Write`/`Edit` na plikach `src/**`, `lib/**`. Krótkofalowo:
to jest część otwartego follow-upu "Stronger hook enforcement" w
`README.md:234-241` — nie blokuje tej analizy.

---

#### M3. `slash-commands: false` w Codex `platform.yaml` nie ma kompensacji

**Evidence.** `runtime/platforms/codex/platform.yaml:14`:
```yaml
slash-commands: false
```

vs Claude `slash-commands: true`. Codex nie ma custom slash commands —
workflow entry jest przez `$build`, `$fix` etc. (Codex skill invocation).
Ale skill invocation **nie ma preamble injection mechanism**, jak już
zidentyfikowane w C1. Więc `slash-commands: false` + brak preamble =
workflow entry bez gates.

**Impact.** Entry point do workflow skilla na Codexie jest proceduralnie
słabszy niż entry point do slash command na Claude Code. To samo co C1,
ale widziane od strony entry UX.

**Severity rationale.** Major, stricte powiązane z C1 — w praktyce
zamykane tym samym fixem.

**Recommendation.** Pokryte przez C1.

---

### Minor

#### m1. Brak `AGENTS.override.md` hint w AGENTS.md jako subtree-scope enforcement

AGENTS.md wspomina `AGENTS.override.md` jako "narrow directory-specific
overrides" ale nie sugeruje użycia go do **wzmacniania** enforcement
w szczególnych obszarach repo (np. `.sage/` workflow rules).

**Recommendation.** Opcjonalnie: pattern "drop stricter AGENTS.override.md
into subtree X if you want tighter rules there". Nice-to-have, nie core fix.

---

#### m2. README.md Codex opisuje "open follow-ups" jako non-blocking

`runtime/platforms/codex/README.md:234-253` wymienia "Stronger hook
enforcement" i "CI-backed regression coverage" jako otwarte follow-upy
"nie blokujące portu". To jest realistic, ale user postrzega port jako
"ready" bez tych elementów, a obecna analiza pokazuje że **enforcement**
jest blokerem dla doświadczenia restryktywności. README bardzo
redukuje ten sygnał.

**Recommendation.** Po zaadresowaniu C1+C2 zaktualizować README żeby
odzwierciedlał nową sytuację enforcement. Po ficie — nie przed.

---

## Synthesis

**Root cause (single sentence).** Port Codexa ma poprawną taksonomię
(workflow skills + AGENTS.md + shared `.sage/`), ale nie ma
odpowiednika dwóch kluczowych mechanizmów enforcementowych z Claude
Code: (1) per-workflow PREAMBLE injection do workflow-activated content,
(2) adversarial Process Constitution w always-on instructions file.

**Pattern across findings.** Wszystkie Critical/Major findings mówią
tę samą rzecz w różnych warstwach: reguły Sage są na Codexie
**opisane**, nie **wyegzekwowane**. Claude Code egzekwuje przez
redundancję (CLAUDE.md + hook context + per-command preamble), Codex
egzekwuje przez jeden kanał (AGENTS.md) i nawet ten kanał jest 2x
słabszy.

**Top priority.** **C1 (PREAMBLE injection) + C2 (AGENTS.md strictness)
razem.** Są to dwie edycje w jednym pliku (`generate-codex.sh`), ale
mapują na dwa różne obszary tego pliku (heredoc AGENTS.md, workflow
skill generation loop). Nie da się naprawić jednej bez drugiej i mieć
parity — PREAMBLE na skillu bez strict AGENTS.md wciąż pozostawia
default state zmiękczony; strict AGENTS.md bez PREAMBLE wciąż
zostawia slotowanie do workflow skilla bez gate reminders.

**M1 (SessionStart hook)** jest runner-up, ale jako wzmacniacz, nie
rdzeń. Ma sens zrobić w tym samym cyklu bo dotyka tego samego generatora.

---

## Scope of remediation

Proponowany scope dla follow-up pracy:

- **Moderate** (3 plików):
  1. `runtime/platforms/codex/setup/generate-codex.sh` — heredoc AGENTS.md + preamble injection dla workflow skills + (opcjonalnie) hook install
  2. `runtime/platforms/codex/hooks/session-start.sh` — rich context injection
  3. `runtime/platforms/codex/README.md` — update sekcji enforcement status

Dodatkowo może być potrzeba dotknięcia jednego-dwóch plików
`sage/core/workflows/*.workflow.md` **tylko jeśli** zdecydujemy że
PREAMBLE powinien żyć w źródle (sharowanym) a nie w generatorze
(per-platform). To architektoniczna decyzja, nie czysta naprawa.

**Rekomendacja:** zrobić to jako `/sage:fix` z Moderate scope (fix plan
→ implementation → verify). Jeśli w trakcie fix plan wyjdzie że
PREAMBLE powinien być sharowanym źródłem (Claude + Codex czytają z
tego samego miejsca) — eskalować do `/sage:architect`.

---

## Out of scope (świadomie)

- Antigravity platform — analiza dotyczy tylko Claude vs Codex deltas
- Tool gating przez PreToolUse (M2) — duży engineering, follow-up osobny
- CI-backed regression gates — osobny track w README
- UX cockpit parity — explicit non-goal portu per README
