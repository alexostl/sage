---
title: "Fix Plan for Codex Enforcement Gap"
type: fix-plan
status: completed
scope: moderate
date: 2026-04-23
version: 2
related_analysis: .sage/docs/analysis-codex-enforcement-gap.md
supersedes_v1_rationale: "User correction — calibration by line-count parity was a proxy, not the outcome. Rewritten after reading Codex docs for native enforcement mechanisms."
files_touched: 7
upstream_pr_target: "xoai/sage"
---

# Fix Plan v2 — Codex Enforcement Gap

## Outcome (the real target)

**Cel:** Agent na Codexie podąża za Sage workflow jako za rulebookiem, nie
traktuje frameworka jako inspirację. Line count, rozmiar pliku, parity
z Claude/Antigravity to **proxies, nie cele** — mogą być konsekwencją
fixa, ale nigdy nie były jego definicją sukcesu.

**Observable behaviors po fixie:**

1. Gdy user na Codexie pisze "add X feature" (keyword build), agent
   **przed napisaniem kodu** sprawdza istnienie `.sage/work/*/spec.md`
   i `plan.md`. Brak → nie implementuje, tworzy spec/plan najpierw.
2. Gdy user pisze "fix bug Y", agent prezentuje root cause z evidence
   przed jakąkolwiek modyfikacją pliku, i zatrzymuje się na `[A]/[R]/[S]`.
3. Przed pisaniem spec/plan agent invokuje `sage_memory_search` (dwa
   wywołania: domain + self-learning).
4. Przy checkpointach agent wkleja actual test output, nie podsumowuje.
5. Przy user correction agent zapisuje self-learning **zanim**
   kontynuuje inną pracę.
6. Na start sesji agent widzi aktywne inicjatywy i nie startuje fresh
   kiedy `.sage/work/` ma treść.

Test: weź 5 zadań z różnych workflowów, patrz na pierwsze 3 tury
agenta. Jeśli w każdym z 5 przypadków agent robi file checks / memory
search / root cause przed skokiem do action — outcome osiągnięty.

## Research findings — Codex-native enforcement mechanisms

Z dokumentacji Codex (developers.openai.com/codex/*), kluczowe dla
tego fixa:

| Mechanizm | Jak działa | Implikacja dla Sage |
|---|---|---|
| **AGENTS.md** | Instruction chain budowany **raz per session** walking root → cwd, `AGENTS.override.md` preferowany nad `AGENTS.md` per level; cap **32 KiB** (`project_doc_max_bytes`); silent file-level truncation gdy przekroczone; nie re-injected per turn; closer-to-cwd wygrywa (appears later) | Rozmiar nieistotny poniżej 32 KiB. Ton i struktura muszą być takie żeby rules pozostały salient przez całą sesję. Front-load constitutional rules. |
| **Skills** | Tylko `name` + `description` eager-loaded do system prompta; full body loaded via file-read **on activation**; **"Do not carry skills across turns unless re-mentioned"** | PREAMBLE w `SKILL.md` = **jednorazowy trigger** przy aktywacji. Nie zastępuje stałej reguły w AGENTS.md. Ale nadal wartościowe jako first-turn framing przy `$build`. |
| **Frontmatter** | Honorowane tylko `name`, `description` | Brak `alwaysApply`, `priority`, `triggerKeywords` — nie da się forsować skills budgetem frontmattera. |
| **PreToolUse** | Intercept **tylko Bash**, nie Write/Edit/Read | Nie da się gatować Edit/Write przez file existence — trzeba UserPromptSubmit. |
| **UserPromptSubmit** | Pre-turn; może `decision: "block"` + inject `additionalContext` | **Killer lever.** Runtime-enforced pre-turn gate, działa **przed** że model zobaczy user prompt. Claude nie ma ekwiwalentu. |
| **SessionStart** | Może inject `additionalContext` na start sesji | Rich context injection — już identyfikowane jako M1. |
| **agents.<name>** | Native subagent framework w `.codex/config.toml` | Można zdefiniować `sage-reviewer` subagent z własnym config_file / AGENTS.md. |
| **features.guardian_approval** | Experimental routing approvals przez reviewer subagent | Operacjonalizuje Rule 5 ("Spec compliance is adversarial") jako separate process. |
| **features.codex_hooks** | Gate flag dla hook system | Wymagane do jakiegokolwiek hook enforcement. Off by default. |

**Kluczowa zmiana myślenia vs v1 plan:**

v1 myślał: "skopiuj Claude pattern, adaptuj do Codex surface". v2 myśli:
"Codex ma inne levery niż Claude. Użyj tych których Claude nie ma
(UserPromptSubmit gate), i dostosuj tekst do faktu że AGENTS.md jest
loaded **once per session, not per turn**."

## Strategy

Priorytetyzuję mechanizmy enforcement po **impact × feasibility**:

### Tier 1 — in scope (realny enforcement, realistic effort)

**S1. UserPromptSubmit gate hook**  
Runtime pre-turn gate. Matchuje keywordy build/fix/architect → sprawdza
`.sage/work/*/` na istnienie odpowiednich artefaktów → jeśli brak,
`decision: "block"` + `additionalContext` redirectujący do "write
spec first per Rule 3 Build". **Non-bypassable prose** — model
zobaczy blocked prompt + replacement context, nie oryginalny prompt.

To jest **single strongest lever** dla outcome "agent podąża za
framework". Dodaję do starter pack (`hooks.example.json` + nowy
`pre-prompt.sh`), doc w `HOOKS.md`. Zachowuję opt-in posture per
Codex `codex_hooks` experimental flag.

**S2. AGENTS.md — rewrite for salience, not parity**  
Cel: rules pozostają salient przez całą sesję mimo że AGENTS.md jest
injected **once** na start. To wymaga:
- **Tight, scannable structure** — krótkie sekcje, nie ściana tekstu
- **Imperative, plain language** — "Before writing code, read X" zamiast "It is recommended that agents read X"
- **Observable compliance signals** — "Agent states 'Sage → [workflow]' before work" zamiast "Agent should be process-aware"
- **Rules closest to cwd win** — trzymać root `AGENTS.md` (repo-root) krótki i ostry; szczegóły/domain rules mogą iść do subdirów gdy relevant

Użyć `@path.md` imports (potwierdzone że Codex je obsługuje) dla
fragmentów które są długie ale reużywalne — np. "Workflow gates"
mogą żyć w `sage/core/constitution/workflow-gates.md` i być
referencyjane z AGENTS.md. To rozwiązuje 32 KiB budget constraint.

**Rozmiar jako output:** tak długie jak potrzeba żeby outcome był
osiągnięty. Nie będzie kalibrowane do ~290-310 linii. Jeśli outcome
osiąga się w 200 liniach — 200. Jeśli wymaga 400 — 400 (pod 32 KiB).

**S3. SessionStart hook — rich context**  
Bez zmian w założeniu vs v1: port rich context z Claude
`sage-session-init.sh` do `session-start.sh`. Kluczowe dla outcome
#6 (agent nie startuje fresh). **Opt-in posture zachowana** —
wymaga `codex_hooks = true`. Ale starter content staje się
wartościowy.

**S4. Workflow skill PREAMBLE — reduced role**  
Zmiana rozumienia: skills **nie persystują przez tury**. PREAMBLE
w `SKILL.md` ma value TYLKO jako first-turn framing przy aktywacji.
Więc:
- Zachowuję injection mechanism (jak v1)
- Treść jest **outcome-driven** — każda linia PREAMBLE musi mieć
  bezpośredni link do observable behavior z listy outcome
- **Odpada strategia "port Antigravity PREAMBLE 1:1"** — nie
  kalibruję pod sibling platform, tylko pod outcome
- Skracam do absolutnego minimum: rules które imho wymagają
  przypomnienia natychmiast przy aktywacji (np. MEMORY FIRST,
  FILE CHECKS, [A]/[R] semantics). Rules których model i tak
  nie zapomni (np. "don't use code blocks") mogą odpaść.

### Tier 2 — optional extension (większa moc, ale rozszerzanie scope)

**S5. `sage-reviewer` subagent + guardian_approval**  
Native Codex mechanism: define `[agents.sage-reviewer]` w template
config, szkielet `AGENTS.md` dla tego subagenta, i wire
`guardian_approval` feature flag. Skutek: gdy user picks `[A]` na
checkpoint, Codex routuje approval przez sage-reviewer (fresh
context, osobny agent, czyta spec/plan adversarially i weryfikuje
zgodność). To jest **najsilniejszy** mechanism dla Rule 5 outcome,
ale wymaga:
- Nowego pliku w template / docs
- Nowej sekcji w generator dla template configa
- Experimental flag — user musi opt-in
- Edukacja w README

**Propozycja:** NIE w scope tego fixa. Dodać jako follow-up w
`README.md` "Optional: stronger checkpoint enforcement via
guardian_approval". Osobny PR jeśli user zdecyduje że warto.
Uzasadnienie: obecny fix już dostarcza S1-S4 które są samowystarczalne
dla outcome. S5 to bonus moc, nie blocker.

### Tier 3 — explicitly out of scope

- `model_instructions_file` replacement — za inwazyjne, outside Codex port scope
- Cross-platform PREAMBLE shared source refactor — upstream decision affecting all 3 generators
- PreToolUse Write/Edit gating — Codex nie wspiera
- Auto-enable `codex_hooks = true` w `.codex/config.toml` przez generator — Codex docs flaga eksperymentalna, user musi opt-in

## Files touched

1. **`runtime/platforms/codex/setup/generate-codex.sh`**  
   - Heredoc AGENTS.md → rewrite for outcome (S2)
   - Workflow skill generation loop → add outcome-focused PREAMBLE injection (S4)
   - Special-case `sage` and `review` skills (jak Claude/Antigravity)

2. **`runtime/platforms/codex/hooks/pre-prompt.sh`** (NEW)  
   - UserPromptSubmit hook implementation (S1)
   - Keyword matcher → `.sage/work/*/` file check → conditional block + redirect

3. **`runtime/platforms/codex/hooks/session-start.sh`**  
   - Rich context port z Claude (S3)

4. **`runtime/platforms/codex/hooks.example.json`**  
   - Dodać `UserPromptSubmit` hook wiring dla `pre-prompt.sh` (S1)

5. **`runtime/platforms/codex/HOOKS.md`**  
   - Update docs: new `pre-prompt.sh` role, kiedy / dlaczego opt-in
   - Rationale linking hook capability do outcome

6. **`runtime/platforms/codex/README.md`**  
   - Update "Current Limits and Posture" + "Open Follow-Up Features"
   - Sekcja o S5 (guardian_approval) jako opcjonalny follow-up

Plik count: **5-6** (zależy czy HOOKS.md + README = 2 plliki czy 1 update).
Wyższy niż v1 (3) bo dodaje się **nowy enforcement mechanism** (S1 hook)
który jest outcome-krytyczny.

**Scope zostaje Moderate** — 3-5 files uzasadnione dla Moderate per
Sage fix workflow definition. Jeśli okaże się że S1 hook wymaga
większego kodu → escalate do /sage:architect.

## Non-goals (świadomie)

- Nie kalibruję line count AGENTS.md do sibling platform
- Nie port 1:1 Claude PREAMBLE — zamiast tego per-workflow PREAMBLE
  driven przez outcome mapping
- Nie dotykam `sage/core/workflows/*.workflow.md`
- Nie dotykam Claude / Antigravity generatorów
- Nie auto-enabluję hook feature flag
- Nie implementuję S5 (guardian_approval subagent) w tym PR

## Verification — outcome-based

Weryfikacja NIE przez line count. Przez **observable behaviors**:

### Regression / generator checks (mechaniczne)

```bash
# Regenerate
bash runtime/platforms/codex/setup/generate-codex.sh .

# AGENTS.md fits 32 KiB budget
wc -c AGENTS.md  # expect < 32768

# Workflow skills have outcome-linked PREAMBLE
for f in .agents/skills/*/SKILL.md; do
  grep -q "RULES (apply to every step" "$f" && echo "OK $f" || echo "NO PREAMBLE $f"
done
# expect OK dla każdego workflow skilla (sage/review special-cased, osobno sprawdzić)

# New hook script is executable and valid JSON on valid input
echo '{"tool_input":{"prompt":"add X"}}' | bash runtime/platforms/codex/hooks/pre-prompt.sh
# expect: exit 0, output parseable JSON

# Existing regression tests still green
bash runtime/platforms/codex/tests/run-regression.sh
```

### Outcome smoke test (behavior)

Po `sage update` na fresh projekcie z Codex:

1. Opt-in do hooks (`codex_hooks = true` + copy starter)
2. Start Codex session w repo
3. Prompt: "add a login button to the header"
4. **Expected**: agent prezenntuje spec proposal + czeka na [A]/[R].
   Nie startuje implementacji. UserPromptSubmit hook blokuje + redirect.
5. Prompt: "the API returns 500 on POST /users"
6. **Expected**: agent robi root cause investigation z evidence przed
   jakąkolwiek zmianą. Prezentuje root cause + czeka na [A].
7. Mid-session correction: "no, that's wrong, the real issue is X"
8. **Expected**: agent wywołuje `sage_memory_store` z self-learning tag
   przed kontynuacją.

Wkleję output smoke testu do verification checkpoint.

### Acceptance criteria

- Wszystkie mechaniczne checks pass
- 5 z 5 scenarios z outcome smoke testu pokazują expected behavior
- Codex regression tests green
- No regression Claude / Antigravity (untouched)

## Risk and rollback

**Risks:**
- **UserPromptSubmit hook blokuje legitimate prompts.** Mitigation:
  keywords matcher starts narrow (tylko "add feature X" / "build Y" /
  "fix Z"), daje redirect zamiast hard block. User może bypass przez
  preferowanie `$build` / `$fix` skill invocation (które może być
  wyłączone z hook matchera).
- **AGENTS.md może przekroczyć 32 KiB.** Mitigation: `wc -c` check
  w verification, jeśli blisko budżetu — pushnij content do `@`
  imports.
- **Opt-in hooks means default user doesn't get S1 enforcement.**
  Mitigation: README jasno mówi że for full enforcement parity z
  Claude, opt-in hooks required. S2-S4 dają substantial improvement
  nawet bez S1.

**Rollback:** `git revert`. Ponieważ fix rozszerza starter pack +
generator, revert wraca do v1 starter pack. `.sage/` untouched.

## PR prep for xoai/sage

- **Branch:** `fix/codex-enforcement-outcome-parity`
- **Title:** "fix(codex): bring enforcement outcome parity via UserPromptSubmit gate + outcome-focused AGENTS.md"
- **PR body:** outcome-based framing — "current Codex adapter leaves
  Sage workflow as inspiration; this PR uses Codex-native
  UserPromptSubmit, enriched AGENTS.md, and per-workflow PREAMBLE to
  enforce Sage rules as strongly on Codex as on Claude Code"
- **Changed files list:** 5-6 as listed above
- **Follow-up note in PR body:**  
  > PREAMBLE injection follows existing Claude + Antigravity
  > per-generator pattern. Consolidation to shared source is out
  > of scope.  
  > Optional stronger enforcement via `features.guardian_approval`
  > and a `sage-reviewer` subagent is documented as follow-up but
  > not implemented here — separate concern, experimental flag.
- **Base:** upstream `main`

## Decision log

- **v1 plan was calibrated by line count parity with sibling
  platforms.** User correction: "line count is proxy, not outcome —
  read Codex docs first." (Rule 6 captured as self-learning
  `652698c30bdc4eb2af55ed03012f8afb`.)
- **v2 plan calibrates by Codex-native enforcement mechanisms**
  identified from docs research. Primary lever changed from "longer
  AGENTS.md" to "UserPromptSubmit gate + outcome-focused AGENTS.md +
  PREAMBLE as first-turn framing".
- **S5 (guardian_approval + sage-reviewer) explicitly deferred** —
  bonus power, not required for outcome, separate PR if user wants.
