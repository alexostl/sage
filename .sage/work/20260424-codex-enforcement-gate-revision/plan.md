---
title: "Plan naprawczy — Codex UserPromptSubmit gate + brakująca verification.md"
slug: 20260424-codex-enforcement-gate-revision
type: fix-plan
scope: moderate
status: completed
phase: verification
parent_initiative: 20260423-codex-enforcement-gap-fix
created: 2026-04-24
owner: alexostl
---

# Plan naprawczy — Codex UserPromptSubmit gate + brakująca verification.md

## Kontekst

Niezależny review (sub-agent, `.sage/decisions.md` wpis 2026-04-24) po
shipowaniu `20260423-codex-enforcement-gap-fix` (commity `aa9c6e3` na
`selfhost`, `9a6f4c2` na `codex-port`) zwrócił verdict
**NEEDS REVISION**. Plan v2 tamtego fixa jest solidny (outcome-driven,
honest deferrals), ale sama implementacja "killer levera" —
UserPromptSubmit gate — ma bugi, które neutralizują gate po pierwszym
builcie i blokują legalne Tier 1 prompty. Dodatkowo brakuje
verification.md z wklejonym outputem (naruszenie Rule 5 na własnym fixie
Sage).

Ten ticket to fix-of-a-fix: domyka enforcement gap prawidłowo, bez
wycofywania niczego co już działa (PREAMBLE, AGENTS.md, session-start,
namespace collision handling, stdin fix — wszystkie zaakceptowane przez
reviewera jako strengths).

## Root cause (z review, evidence-backed)

| # | Finding | Lokalizacja | Evidence |
|---|---------|-------------|----------|
| **C1** | `any_initiative_has()` jest global-scope → build gate przechodzi po pierwszym initiative'ie | `runtime/platforms/codex/hooks/pre-prompt.sh:82-88` | Reviewer odtworzył: seed `/tmp/prior-init/.sage/work/old-feature/{spec,plan}.md`, prompt "build a totally new payments module" → passthrough, zero block |
| **M2** | Fix-keyword gate hard-blokuje każdy prompt z `fix|debug|broken|crash|failing|bug|error` | `pre-prompt.sh:127-154` | False positives: "fix the typo in README", "fix indentation", "add a debug log to auth handler", "broken image on landing page". Sprzeczność z `fix.workflow.md:193-197` (Surgical carve-out, 1-2 pliki, bez planu) |
| **M3** | Brak `verification.md` z wklejonym outputem smoke/regression/byte-check | `.sage/work/20260423-codex-enforcement-gap-fix/` | Istnieje tylko `plan.md`; dowód verification jest streszczony w jednym paragrafie `decisions.md` — naruszenie Rule 5 "paste actual output, don't summarize" |
| **M4** | `tests/run-regression.sh:36` używa `rg -Fq` | `runtime/platforms/codex/tests/run-regression.sh` | Czyste macOS (bez Homebrew ripgrep) → "rg: command not found". Decisions entry z 2026-04-23 nawet wspomina "codex regression green with rg shim" — czyli podczas tamtej weryfikacji runner musiał alias-ować rg |
| **M5** | `$skill` passthrough whitelist nie zawiera `$status`, `$learn`, `$map`, `$autoresearch`, `$design-review` | `pre-prompt.sh:52-55` | AGENTS.md "Fast entry in Codex" reklamuje `$status` — user typuje `$status debug the build` → trafia w fix gate bo `$` prefix nie jest rozpoznany |

Root cause dla wszystkich pięciu findingów jest tego samego typu:
**gate logic overfituje do happy path pierwszego initiative'u i zamyka się
na realistic usage patterns**. Verification.md to osobna dimension
(self-discipline na Rule 5).

## Scope: Moderate (3 pliki modified, 1 nowy)

Per `fix.workflow.md` Moderate = 3-5 plików → wymaga plan.md przed
implementacją. Stop sign: gdy w trakcie implementacji pojawi się
konieczność dotknięcia 6. pliku, eskalacja do `$build` lub osobny
ticket.

**Pliki w scope:**

1. `runtime/platforms/codex/hooks/pre-prompt.sh` (major changes — fixy C1, M2, M5, Minor #11)
2. `runtime/platforms/codex/tests/run-regression.sh` (swap `rg` → `grep`)
3. `.sage/work/20260423-codex-enforcement-gap-fix/verification.md` (NOWY, Rule 5 compliance)
4. `runtime/platforms/codex/HOOKS.md` (tuning dokumentacja: nowa semantyka gate'u + lista skills w passthrough)

**Nie w scope (jawnie deferred):**

- Minor #6 (size escape hatch `@import`) — dopiero gdy AGENTS.md > ~20 KiB. TODO w HOOKS.md wystarczy.
- Minor #7 (PEP 585 `list[str]` annotation) — brak realnego ryzyka na dev machine'ach z py≥3.9. Usunę przy okazji skoro i tak dotykam pliku.
- Minor #8 (surface drift między AGENTS.md "fix behavioral" a hookiem blokującym) — po fixie M2 hook staje się "behavioral with sensible Tier 1 pass-through", czyli dokumentacja i hook się zbliżą. Jeśli zostanie drift, osobna karta.
- Minor #9 (stale `IMPLEMENTATION_READY_HANDOFF.md` na `codex-port`) — osobny housekeeping commit tylko na codex-port, nie łączyć z tym fixem.
- Minor #10 (nullglob polish w session-start) — kosmetyka, nie łamie nic.
- `sage-reviewer` + `guardian_approval` — zostaje deferred zgodnie z planem v2.

## Changes w kolejności implementacji

### 1. `pre-prompt.sh` — przepisanie gate logiki

**1a. CRITICAL #1 — per-initiative / status-aware build gate**

Zamiana `any_initiative_has(name)` na funkcję, która zwraca listę
initiative'ów w stanie `status: in-progress` (albo dowolnym nie-terminalnym
— `draft`, `in-progress`, `under-review`). Build gate sprawdza:

- Czy jest **jakikolwiek** initiative w nie-terminalnym status?
  - TAK → dla **każdego** z nich sprawdź czy ma `spec.md` + `plan.md`.
    - Jeśli co najmniej jeden ma oba → passthrough (user kontynuuje aktywną pracę).
    - Jeśli żaden nie ma kompletu → block (user rozpoczyna implementację bez gotowych artefaktów).
  - NIE → block z redirect "napisz spec.md + plan.md do nowego `.sage/work/<slug>/`".

To nie jest perfekcyjne (nie rozwiązuje casa "user ma ukończony initiative A
i chce zacząć nowy initiative B"), ale eliminuje dominujący tryb
globalnego passthrough. Jeśli user ma aktywny initiative B bez plików —
gate zadziała. Jeśli ma aktywny initiative A z plikami i chce zacząć B —
akceptujemy jako false negative (user i tak zobaczy PREAMBLE z
`$build`-a).

**Alternatywa odrzucona:** parse initiative slug z prompta (regex
`(?:for|dla|in)\s+([a-z0-9-]+)`) — krucha, false negatives gorsze niż
obecne false positives.

**1b. MAJOR #2 — Tier 1 passthrough dla fix-keyword gate**

Rozszerzenie `TINY_RE` (już istniejącego dla Tier 1 pytań) o typowe Tier 1
fix operations. Propozycja:

```python
TIER1_FIX_RE = re.compile(
    r'\b(typo|typos|indentation|indent|whitespace|formatting|'
    r'rename|renaming|comment|comments|log|logging|'
    r'import|imports|lint|linting|prettier|eslint)\b',
    re.IGNORECASE
)
```

Logic: jeśli prompt matchuje FIX_RE **i** TIER1_FIX_RE → passthrough z
`additionalContext` ("Tier 1 fix detected — proceeding. If this turns out
to be deeper, escalate to `$fix`.").

Świadomy tradeoff: może złapać "fix the logging system architecture" jako
Tier 1. Akceptowalne — PREAMBLE i AGENTS.md Rule 4 dalej wymuszają root
cause gdy scope się okaże większy.

**1c. MAJOR #5 — pełna lista `$skill` w passthrough**

Zamiana hard-coded listy na pattern-match:

```python
EXPLICIT_SKILL_RE = re.compile(r'^\s*[$/][a-z][a-z-]*(?:\s|$)')
```

Łapie wszystkie skille (obecne i przyszłe) przez prefix `$` lub `/`.
Tradeoff: łapie też `/bin/bash` gdyby user kiedyś wklejał raw command —
akceptowalne, to nie jest build-prompt szept.

**1d. Minor #11 — zawężenie `BUILD_RE`**

Obecny: `\b((?:please\s+)?(?:build|implement|add|create|develop|ship|deliver|introduce))\b`
Problem: "add tests for the utils module" matchuje bez kontekstu.

Propozycja: wymagać noun po czasowniku:

```python
BUILD_RE = re.compile(
    r'\b(?:please\s+)?'
    r'(?:build|implement|add|create|develop|ship|deliver|introduce)'
    r'\s+(?:a\s+|an\s+|the\s+|new\s+)?'
    r'(?:feature|module|component|page|endpoint|api|system|service|'
    r'integration|flow|screen|view|route|handler|migration|schema|'
    r'workflow|skill|hook|platform|adapter)',
    re.IGNORECASE
)
```

Tradeoff: mniej false positives, ale możemy przegapić "add a search
function" (search nie w słowniku). Akceptowalne — gate jest pierwszą
linią obrony, nie jedyną; PREAMBLE `$build`-a to druga.

**1e. Usunięcie PEP 585 annotation**

Zamiana `list[str]` → usunięcie adnotacji (funkcja jest prywatna,
annotation nic nie daje). Rozwiązuje Minor #7 po drodze.

### 2. `tests/run-regression.sh` — swap `rg` → `grep`

Linia 36 (i potencjalnie inne). Zamiana `rg -Fq "pattern" "file"` na
`grep -Fq "pattern" "file"`. `grep -F` jest w POSIX, dostępne wszędzie.

### 3. `.sage/work/20260423-codex-enforcement-gap-fix/verification.md` — NOWY artefakt

Struktura:
- **Hook smoke scenarios (7)** — komenda + wklejony stdout każdego scenariusza
- **Regression test** — `bash runtime/platforms/codex/tests/run-regression.sh` + output
- **AGENTS.md byte check** — `wc -c runtime/platforms/codex/*/AGENTS.md.template` lub generator + generated file
- **PREAMBLE coverage** — output skryptu sprawdzającego że 16/16 workflow skills carry PREAMBLE
- **Verdict per outcome** z planu v2

To retroaktywna verification dla `20260423` — ticket `20260424` sam też
będzie mieć swoją verification section (na końcu tego planu).

### 4. `HOOKS.md` — update

Sekcja "Tuning the pre-prompt gate":
- Nowy behavior: per-initiative (status-aware), nie global-scope
- Lista Tier 1 fix keywords (co przechodzi bez bloku)
- Pattern dla `$skill` passthrough
- TODO dla Minor #6 (size escape hatch) jako future consideration

## Verification plan (dla tego ticketa)

Przed oznaczeniem `completed`:

1. **Unit smoke nowego `pre-prompt.sh`** — tabela 8 scenariuszy:
   - empty `.sage/work/` + "build a widget" → BLOCK
   - `.sage/work/A/{spec,plan}.md` status:completed + "build a new widget" → BLOCK (no in-progress initiative)
   - `.sage/work/A/{spec,plan}.md` status:in-progress + "build something" → PASS
   - `.sage/work/A/` status:in-progress bez plan.md + "build something" → BLOCK
   - "fix the typo in README" → PASS (Tier 1 fix passthrough)
   - "fix the auth bug" → BLOCK (not Tier 1)
   - "$status debug the build" → PASS ($skill prefix)
   - "add tests for the utils module" → narrow BUILD_RE → PASS (no noun match) **lub** BLOCK if wtedy in-progress ma pełne pliki — zaakceptuj obie.

2. **Regression test** — `bash runtime/platforms/codex/tests/run-regression.sh` na czystym macOS bez rg. Musi przejść.

3. **Byte count** — `wc -c` na AGENTS.md po regeneracji. Musi być < 32 KiB.

4. **PREAMBLE coverage** — skrypt `grep -l "PREAMBLE" .agents/skills/*/SKILL.md | wc -l` po regeneracji. Musi być ≥ 16.

5. **verification.md** dla `20260423` istnieje z wklejonym outputem wszystkich powyższych.

Output każdego z tych kroków → wklejony do `verification.md` tego ticketa
(`.sage/work/20260424-codex-enforcement-gate-revision/verification.md`) **przed** completion checkpoint.

## Deployment

Identyczny wzorzec jak `20260423`:

1. Commit na `selfhost` (wszystkie 4 pliki).
2. Switch na `codex-port`, `git checkout selfhost -- <paths>` dla 3 plików kodu + dokumentacji (verification.md NIE idzie do repo — jest w `.sage/` gitignored).
3. Stop → user [A] → push oba branche.

Nie łączę tego z naprawą Minor #9 (`IMPLEMENTATION_READY_HANDOFF.md`
stale na codex-port) — ta wymaga osobnego commitu na codex-port only.

## Success criteria (observable)

- ✅ `pre-prompt.sh` blokuje build-prompt gdy nie ma initiative w nie-terminalnym status z kompletem spec+plan (potwierdzone smoke).
- ✅ Tier 1 fix-prompty ("fix typo", "fix indent") przechodzą (potwierdzone smoke).
- ✅ `$status`, `$learn`, `$map`, `$autoresearch`, `$design-review` przechodzą bez blokady (potwierdzone smoke).
- ✅ `tests/run-regression.sh` przechodzi na czystym macOS bez ripgrep (potwierdzone command + output).
- ✅ `.sage/work/20260423-codex-enforcement-gap-fix/verification.md` istnieje i zawiera wklejony output (nie streszczenie) wszystkich 5 wymiarów verification tamtego ticketa.
- ✅ `.sage/work/20260424-codex-enforcement-gate-revision/verification.md` istnieje z analogicznym wklejonym outputem dla tego ticketa.
- ✅ Commity na obu branchach, identyczne diffy dla 3 plików kodu (pre-prompt.sh, run-regression.sh, HOOKS.md). verification.md jako `.sage/` state nie idzie do repo.

## Token / overhead impact

- Zero dodatkowego zawsze-włączonego kontekstu (AGENTS.md bez zmian).
- HOOKS.md rośnie o ~40 linii (dokumentacja); nie ładuje się jako system prompt.
- `pre-prompt.sh` netto zmienia się o ~30-40 linii (nowa logika `initiatives_in_progress()` + Tier 1 fix passthrough + pattern-based `$skill`). Overhead wykonania hook'a pomijalny (< 10 ms per turn, scanning `.sage/work/*/`).

## Ryzyka

- **Status frontmatter nie zawsze poprawny.** Jeśli user zostawi initiative w `status: in-progress` po zakończeniu pracy, gate będzie zbyt permisywny. Mitigation: Rule 7 + decisions.md check przy completion checkpoint, plus session-start już pokazuje in-progress initiative'y.
- **`TIER1_FIX_RE` może przepuścić non-trivial fix.** Mitigation: PREAMBLE `$fix`-a wymusza root cause niezależnie od gate'u.
- **Regeneration w verification może nie odtworzyć dokładnie commitniętej wersji.** Mitigation: verification komendy run na czystym generate, nie na już-zedytowanym drzewie.

## Otwarte decyzje

**D1** — czy zawęzić `BUILD_RE` (Minor #11) teraz, czy osobna karta?
  - Za teraz: już dotykam tego pliku, cost ~5 linii zmian.
  - Przeciw: może wprowadzić inne false negatives których nie wychwycę w smoke.
  - **Default: robię teraz.**

**D2** — czy status:in-progress ma być jedynym akceptowanym statusem, czy też `draft` i `under-review`?
  - **Default:** wszystkie nie-terminalne (`draft`, `in-progress`, `under-review`). Terminalne (`completed`, `abandoned`) → nie liczą się do "user ma aktywną pracę".

**D3** — czy TODO dla Minor #6 (`@import` size escape) ląduje w HOOKS.md czy w README.md?
  - **Default:** HOOKS.md ("Future considerations" section obok current limits).

Decyzje zaznaczone jako **Default** pójdą w implementacji, chyba że user poprawi.

## Sign-off

Plan czeka na `[A] Approve` / `[R] Revise` / `[S] Skip review`.
Po `[A]` startuje implementacja w kolejności: pre-prompt.sh → run-regression.sh → HOOKS.md → verification.md(s) → dual-branch commit → push pending confirmation.
