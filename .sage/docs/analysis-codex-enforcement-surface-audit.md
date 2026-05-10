---
title: "Codex Enforcement Surface Audit — after two remediation cycles"
type: analysis
status: completed
date: 2026-04-24
scope: custom
artifact_prefix: analysis
supersedes_partial: analysis-codex-enforcement-gap.md
related:
  - CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md
  - .sage/docs/analysis-codex-enforcement-gap.md
  - .sage/work/20260423-codex-enforcement-gap-fix/plan.md
  - .sage/work/20260424-codex-enforcement-gate-revision/plan.md
  - runtime/platforms/codex/hooks/pre-prompt.sh
  - runtime/platforms/codex/README.md
  - runtime/platforms/codex/HOOKS.md
  - AGENTS.md
  - .agents/skills/fix/SKILL.md
  - .agents/skills/build/SKILL.md
---

# Codex Enforcement Surface Audit

## Question

Po dwóch cyklach remediation (`20260423-codex-enforcement-gap-fix`,
`20260424-codex-enforcement-gate-revision`) review
`CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md` dalej daje 5/10 na Sage
compliance. Pytanie: **które surface'y enforcement realnie wymuszają
regułę, a które są tylko opisem?** I: **jaki jest teoretyczny ceiling
Codexa bez wyjścia poza LLM-text?**

Prior analiza (`analysis-codex-enforcement-gap.md`, 2026-04-23)
zidentyfikowała dwa Critical gaps — brak PREAMBLE injection + słaby
AGENTS.md — i oba zostały zamknięte. Ten audyt patrzy na co **zostało**
po remediation: residual bypass paths, ułomność Codex hook surface,
i czy LLM-text sufit jest zgodny z user'owym celem 90-95%.

## Methodology

Dla każdego surface'u enforcement mierzę 4 wymiary:

1. **Delivery mechanism** — w jaki sposób treść dociera do agenta (system
   prompt, pre-turn injection, on-demand read, reference-only).
2. **Persistence** — czy treść jest always-on, per-turn, per-workflow,
   czy jednorazowa.
3. **Bypass difficulty** — co agent musi zrobić żeby ominąć (tekstowy
   nakaz ≠ mechaniczna bariera).
4. **Compliance signal observability** — czy mamy zewnętrzny sposób
   wykryć że reguła nie zadziałała.

Plus: mapowanie 7 findingów z raportu `019dbe38` na konkretne surface'y
i identyfikacja bypass path (transcript-linked).

---

## Surface inventory (6 surface'ów)

### S1. AGENTS.md (always-on constitution)

- **Delivery.** Codex czyta root → cwd walk **raz per sesja**. Injekcja
  do system prompt.
- **Persistence.** Always-on cały session, ale **tylko jednorazowo
  załadowane** — nie re-injektowane per turn.
- **Size.** 313 linii / ~12 KB (cap Codex: 32 KB).
- **Bypass difficulty.** Niska — agent w turnie N może pominąć reguły,
  bo AGENTS.md "zakończyło mówienie" po startupie.
- **Compliance signal.** Jeśli AGENTS.md wymaga "first line: `Sage → …`"
  — brak tej frazy jest obserwowalny zewnętrznie (regex na transcript).
- **Current state:** po remediation zawiera 8 reguł + Workflow Gates +
  Tier + Compliance signals + Interaction Zones + Learning Triggers.
  Parity z CLAUDE.md w mocy reguł.

### S2. Workflow skill PREAMBLE (injected on `$skill` invocation)

- **Delivery.** `.agents/skills/<workflow>/SKILL.md` — pierwsze
  ~30 linii to `RULES (apply to every step — non-negotiable)` block.
  Injekcja do context kiedy user wpisze `$build`/`$fix`/`$architect`.
- **Persistence.** Per-workflow activation — treść czytana przy
  invocation, utrzymuje się w tej sesji ale nie jest re-load'owana bez
  ponownej invocation.
- **Bypass difficulty.** Średnia — agent może wejść w workflow bez
  explicit `$skill` invocation (free-form prompt "fix the bug"), co
  omija PREAMBLE. `pre-prompt.sh` to częściowo rekompensuje przez
  redirect, ale redirect dostarcza tekst, nie pełnego skilla.
- **Compliance signal.** PREAMBLE wymaga fraz typu `Sage: Entering
  [PHASE]` — brak frazy = miss.
- **Current state:** po remediation 16/16 workflow skills niesie
  PREAMBLE. Mocny surface dla tych kto używa `$skill` fast entry.

### S3. Direct skill bodies (`.agents/skills/<name>/SKILL.md`)

- **Delivery.** Codex loaduje metadane (name + description) eagerly na
  start sesji; body on-demand gdy agent zdecyduje się "aktywować" skilla.
- **Persistence.** Jednorazowa aktywacja — po przeczytaniu body nie
  wraca automatycznie; agent decyduje czy re-read.
- **Bypass difficulty.** Wysoka — agent może nigdy nie aktywować skilla
  jeśli nie uzna że jest potrzebny.
- **Compliance signal.** Brak — aktywacja skilla to wewnętrzna decyzja
  agenta, niewidoczna w transcript chyba że skill coś wyemituje.
- **Current state:** ~60 direct skills (memory, self-learning, user-interview
  itd.) obecne. Enforcement = zero.

### S4. Hooks (opt-in runtime gates)

Codex hook surface to **4 events** aktualnie w starter pack:

| Event | Script | Mechanika | Can-block? |
|---|---|---|---|
| SessionStart | `session-start.sh` | informational context | No (stdout only) |
| UserPromptSubmit | `pre-prompt.sh` | pre-turn gate | **Yes** (`decision: "block"` + `additionalContext`) |
| PreToolUse (Bash) | `pre-bash.sh` | narrow destructive-command block | Yes (Bash only) |
| PostToolUse (Bash) | `post-bash.sh` | review reminder | No (stdout only) |

**Niedostępne w current Codex hook docs:** `Stop` hook, PreToolUse dla
Write/Edit/apply_patch. Windows support disabled upstream.

- **Delivery.** Mechaniczna — hook runtime fires przed prompt/bash.
- **Persistence.** `UserPromptSubmit` — jeden hook per turn. Jeśli
  agent w turnie zrobi investigation + implementation w tej samej
  turze, `pre-prompt.sh` widzi tylko początek (prompt usera), nie widzi
  kolejnych edit calls.
- **Bypass difficulty.** **Kluczowa luka:** po redirect `pre-prompt.sh`
  agent dostaje zmodyfikowany context i **dalej odpowiada w tym samym
  turnie**. Nie ma drugiego "gate fire" przed tool calls.
- **Compliance signal.** Mocny — block/pass jest logowalny, additional
  context jest deterministyczny.
- **Current state:** po `20260424` hook jest status-aware + Tier 1
  passthrough + pattern-based `$skill` whitelist. Solidny, ale one-shot.

### S5. Frontmatter directives (`.sage/work/<slug>/*.md`)

- **Delivery.** Pośrednio — agent ma READ access do `.sage/work/`, ale
  nic nie wymusza żeby wyczytał frontmatter przed akcją.
- **Persistence.** Plik na dysku — zawsze dostępny, nigdy
  injektowany automatycznie.
- **Bypass difficulty.** Wysoka — agent może pominąć.
- **Compliance signal.** Obserwowalny zewnętrznie przez file check
  (status, phase, type) — idealna warstwa dla "check filesystem, not
  agent's report".
- **Current state:** `pre-prompt.sh` już używa frontmatter `status:` do
  decyzji o build gate. `phase:` field istnieje w plikach, ale nie jest
  używany przez żaden hook ani gate.

### S6. Subagents (fresh context)

- **Delivery.** Agent spawn przez Task-like mechanism (w Codexie
  `[agents.<name>]` w config + invocation z main agenta).
- **Persistence.** Jeden-shot — fresh context, wraca verdict.
- **Bypass difficulty.** Wysoka dla "czy odpalić" (decyzja main agenta);
  niska dla "czy uwierzyć verdictowi" (jeśli spawn, main agent zwykle
  honoruje).
- **Compliance signal.** Mocny gdy odpalony — verdict jest
  deterministyczny, reviewer ma fresh view.
- **Current state:** Brak mandatory subagent spawn w workflow gates.
  Jedyne miejsce: `fix.workflow.md` Step 2 mówi "On [A]: Run auto-review"
  — ale to tekst, nie mechaniczny fire. W raporcie `019dbe38` Fermat,
  Singer, Euler zostali spawnowani **dopiero po korekcie usera**.

---

## Enforcement strength matrix

| Surface | Bypass difficulty | Compliance signal | Current Δ compliance | Comment |
|---|---|---|---|---|
| S4 UserPromptSubmit | Low (one-shot) | **High** (log) | +15pp | Strongest native lever, ale sufit ~+20pp |
| S2 Workflow PREAMBLE | Medium | Medium (exact strings) | +10pp | Działa tylko na `$skill` entry |
| S1 AGENTS.md | Low | Medium | +8pp | Always-on ale salient tylko pierwsze turny |
| S5 Frontmatter | Low | **High** (file check) | +5pp | Nie w pełni wykorzystany — tylko `status:`, brak `phase:` |
| S6 Subagents | Low (decyzja spawna) | **High** (verdict) | +3pp | Mandatory by teoretycznie dawał +10pp |
| S3 Direct skill bodies | Very low | Low | +2pp | Enforcement zero, knowledge layer only |

Sumarycznie: obecne surface'y jeśli wszystkie działały na 100% → ~+40pp
od 0% baseline. W praktyce obserwujemy ~+40-50pp → 45-55% compliance,
czyli surface'y działają z efektywnością ~85% swojego teoretycznego
maksimum. Problem nie jest w tym że surface'y są źle napisane — problem
jest że **sufit surface-stacku jest strukturalnie niski**.

---

## Findings → surfaces mapping (empirical bypass paths)

Mapowanie 7 findingów z raportu `019dbe38` na surface, który powinien
był je zatrzymać, plus zaobserwowana bypass path.

### Finding #1 — Implementation przed root-cause gate (Critical)

- **Should-catch surface:** S4 `pre-prompt.sh` FIX gate (redirect on
  fix keyword).
- **Bypass observed:** Gate **zadziałał** (prompt match, redirect do
  root-cause), ale agent w **tym samym turnie** po redirect zrobił
  investigation + jump to code. Second turn nie wystąpił bo nie było
  break między phases.
- **Why:** `UserPromptSubmit` jest one-shot per turn. Po injekcji
  `additionalContext` agent kontynuuje w obrębie tego samego turnu,
  a nie ma hooka na Write/Edit do zatrzymania go.

### Finding #2 — Zła diagnoza, subagent złapał (Critical)

- **Should-catch surface:** S6 Subagent review (fix workflow Step 2
  auto-review).
- **Bypass observed:** Subagent spawnowany `dopiero po korekcie usera`
  (transcript line 361). Workflow mówi "On [A]: Run auto-review" jako
  tekst. Agent pominął.
- **Why:** "On [A]: Run auto-review" to nie jest mechaniczna reguła —
  to napisana instrukcja. Agent w bias'ie "ship fast" ją pomija.

### Finding #3 — Backfilled artifacts (Major)

- **Should-catch surface:** S5 Frontmatter + S4 PREAMBLE Moderate fix
  scope gate.
- **Bypass observed:** Agent zaczął Moderate fix bez plan.md; plan.md
  powstał post-hoc (transcript line 649).
- **Why:** Brak phase tracker mechanizmu. Żaden gate nie sprawdza
  "this initiative is phase: planning but plan.md is missing → block".

### Finding #4 — Close-out (commit/push/rollout) niewykonany (Major)

- **Should-catch surface:** Żaden obecny. Codex nie ma Stop hook.
- **Bypass observed:** Agent po verification.md powiedział "done",
  user musiał przypomnieć o commicie (transcript line 1096) i o branch
  rollout methodology (line 1119).
- **Why:** Close-out jest opisany w workflow Step 6 ale brak:
  (a) mechanizmu self-check na dirty tree,
  (b) scripted close path,
  (c) file-on-disk verification że close działania wykonane.

### Finding #5 — Brak phase strings (Major)

- **Should-catch surface:** S2 PREAMBLE wymaga exact strings.
- **Bypass observed:** Agent paraphrased zamiast exact
  `Sage: Entering UNDERSTAND phase`.
- **Why:** Wymaganie jest w tekście skilla, ale nic nie gate'uje na
  brak frazy. Transcript search zewnętrznie je wyłapuje → mamy
  compliance signal, **ale nie mamy forcing function**.

### Finding #6 — Ten sam pattern w /build (cross-thread) (Major)

- **Should-catch surface:** S4 build gate + S2 build PREAMBLE.
- **Bypass observed:** Thread `019dbf41` — agent wszedł w `sage:build`,
  napisał spec/plan, po czym **switchnął live symlink** zanim
  zatrzymał się na approve (transcript line 161). User musiał pytać
  "czemu mnie nie prosisz o approve" (line 259).
- **Why:** Mutacja external state (symlink swap) nie jest
  gate'owana — PreToolUse Bash mógłby, ale current `pre-bash.sh` łapie
  tylko destructive patterns, nie "risky global state change".

### Finding #7 — Brak failing-test-first (Minor)

- **Should-catch surface:** S2 PREAMBLE + verification.md format.
- **Bypass observed:** Workflow show verification i regression, brak
  explicit "pre-fix reproducer" sekcji.
- **Why:** verification.md template nie ma slota na pre-fix reproducer.
  Agent nie wypełnia czegoś czego nie ma w template.

---

## Bypass taxonomy

Sprowadzając 7 findingów do klas bypass:

1. **One-shot gate bypass (#1, #6)** — gate strzela raz per turn;
   agent kontynuuje w tym samym turnie po redirect.
2. **Text-only mandate (#2, #5)** — reguła jest napisana, nie ma
   mechanicznego enforcement.
3. **Missing phase/state tracker (#3, #4, #6)** — brak disk-backed
   state machine która sprawdzi czy phase-specific artifacts istnieją
   przed advance.
4. **Missing close-out gate (#4)** — brak Stop hooka, brak scripted
   close, brak post-verification check.
5. **Missing template slot (#7)** — template/artifact format nie
   wymusza sekcji, więc sekcja się nie pojawia.

---

## Lever ranking (cost × Δ compliance)

Każdy lever oceniony: koszt implementacji (dni), Δ compliance
(pp w sufitowej estymacji), klasa (text-only / infra-hybrid / pure-infra).

| Lever | Cost | Δcc | Class | Closes |
|---|---|---|---|---|
| **L1.** Sticky `additionalContext` injection w `pre-prompt.sh` na każdym turnie (nie tylko block) z active initiative summary + phase + missing artifacts | 0.5d | +5-8pp | text | #1, #3, #6 soft |
| **L2.** verification.md template z wymaganymi sekcjami (pre-fix reproducer, close-out checklist) + `pre-prompt.sh` sprawdza ich obecność przed sign-off | 0.5d | +4-6pp | hybrid | #4, #7 |
| **L3.** Phase tracker: `phase:` frontmatter field, `pre-prompt.sh` wymaga matching artifact dla phase (planning→plan.md, implementation→plan.md + tests) | 1d | +6-8pp | hybrid | #3, #6 |
| **L4.** `bin/sage-close <slug>` atomic script (commit + dual-branch + push + close verification) + workflow PREAMBLE wskazuje go jako **jedyną** sanctioned ścieżkę | 1d | +5-7pp | infra | #4 |
| **L5.** Git pre-commit hook wymagający verification.md z pasted output + close-out section dla Moderate+ initiatives | 0.5d | +4-6pp | **pure-infra** | #4 mech |
| **L6.** Subagent review w `[agents.sage-reviewer]`, mandatory spawn na root-cause gate i fix scope gate, verdict binding via pre-commit hook | 2-3d | +7-10pp | hybrid | #2 mech |
| **L7.** Phase strings validator — prosty skrypt który grepuje transcript za "Sage: Entering [PHASE]" i raportuje; uruchamiany post-session | 0.5d | +2-3pp (obserwowalność, nie forcing) | external | #5 |
| **L8.** PreToolUse Bash gate rozszerzony na "risky mutations" (symlink swap, global path writes, `npm install -g`, `sage update`) wymagające active spec/plan | 1d | +3-5pp | infra | #6 |

**Kombinacje:**

- **L1+L2** (1d): text-only sticky + template = +9-14pp. Sufit: ~65-70%.
- **L1+L2+L4+L5** (2.5d): dodanie sage-close + git hook = +18-27pp.
  Sufit: ~75-82%.
- **L1+L2+L3+L4+L5** (3.5d): + phase tracker = +24-35pp. Sufit: ~80-87%.
- **L1..L6** (5-6d): full hybrid z mandatory reviewer = +31-45pp.
  Sufit: ~85-92%.

---

## Ceiling analysis — czy 90-95% osiągalne

**Krótka odpowiedź: nie bez wyjścia poza LLM-text.**

### Dlaczego 95% wymaga infrastruktury poza Codexem

1. **Codex hook surface jest ułomny w kluczowym miejscu.**
   - Brak Write/Edit/apply_patch PreToolUse → nie można blokować
     modyfikacji kodu przed zatwierdzeniem gate'u.
   - Brak Stop hook → nie można walidować close-out po session end.
   - UserPromptSubmit jest one-shot → agent po redirect kontynuuje
     w tym samym turnie; nie ma drugiego fire point.

2. **Text-based enforcement asymptotuje ~75-80%.**
   Każda dodatkowa warstwa tekstu (AGENTS.md beefup, PREAMBLE, sticky
   reminder) ma diminishing returns. Agent już czyta ~15-20 KB reguł
   na start sesji; dodanie kolejnych 5 KB na turn nie skaluje w
   zachowaniu liniowo. Co więcej: duża objętość tekstu **obniża**
   salience krytycznych reguł (efekt rozcieńczenia).

3. **Bias modelu jest głębszy niż jeden turn.**
   Raport `019dbe38` i cross-thread `019dbf41` pokazują że to nie jest
   ignorancja konkretnej reguły — to `default Codex "persist
   end-to-end" bias overrides the framework unless actively
   constrained`. "Actively constrained" wymaga infra, nie instrukcji.

4. **Compliance signal obserwowalny ≠ compliance wymuszony.**
   Mamy już teraz mocne compliance signals (frazowe, filesystemowe).
   Obserwowalność daje post-hoc audit, nie pre-action block.

### Co by dało 95% (hipotetycznie)

Osobna warstwa infra poza Codexem:

- **Wrapper wokół apply_patch** który sprawdza `.sage/work/<active>/`
  state przed zezwoleniem na file edit. Wymaga custom runtime (nie
  Codex default).
- **`sage-supervisor` daemon** obserwujący `.sage/` state + git state,
  publikujący verdict do hook'a. Wymaga własnego procesu.
- **Reviewer subagent z git pre-commit binding** + git hook odrzuca
  commit bez reviewer sign-off. To jest realistic — git pre-commit to
  istniejąca infra, nie Codex-specific. **Najlepszy stosunek effort
  vs Δ compliance dla 90%+ ceiling.**

### Realistic ceilings

| Stack | Ceiling | Effort |
|---|---|---|
| Current (po 20260423 + 20260424) | **45-55%** | — |
| + L1+L2 (sticky + template) | 65-72% | 1d |
| + L1+L2+L4+L5 (+ sage-close + git pre-commit) | 78-85% | 2.5d |
| + L1..L6 (pełny hybrid z reviewer subagent) | 85-92% | 5-6d |
| + external supervisor process | 92-96% | 8-12d |
| + platform z Write/Edit hook (nie Codex dzisiaj) | 95-98% | platform migration |

**User'owy target 90-95% jest osiągalny, ale wymaga L1..L6** (Bucket
"pełny hybrid") + akceptacji że ostatnie 5-8pp do 95% musi przyjść od
reviewer subagent **z binding verdictem** (czyli nie tylko spawn, ale
odmowa commitu jeśli review fail).

---

## Recommendation (dla decyzji o workflow next)

Na podstawie tego audytu, trzy ścieżki dalej:

[1] **Fix-Moderate: L1+L2 (tekst-only)** — 1 dzień, +15-20pp, sufit ~65-72%.
   Najszybsze ROI. Nie osiąga user targetu 90%.

[2] **Build-Standard: L1+L2+L4+L5 (hybrid bez reviewera)** — 2-3 dni,
   +25-35pp, sufit ~78-85%. Dodaje `sage-close` i git pre-commit hook.
   **Najlepszy compromise.** Zamyka findings #1, #3, #4, #7 mocno;
   #2, #6 częściowo.

[3] **Architect: L1..L6 (pełny hybrid z reviewer subagent)** — 5-6 dni,
   +35-45pp, sufit ~85-92%. Osiąga user target 90% z marginesem.
   Wymaga brief.md + milestone plan (fazowany: hybrid → phase tracker
   → reviewer binding).

**Moja rekomendacja:** jeśli 90% jest hard target → [3]. Jeśli 80%
jest acceptable i chcemy szybki ROI → [2]. [1] jest tylko jeśli chcemy
zamknąć szybko największe findings (#1, #4) bez inwestycji w infra.

---

## Open questions dla user

**Q1.** Czy "90-95% compliance" znaczy per-turn compliance (każdy turn
respectuje regułę), czy per-workflow compliance (każdy workflow kończy
się bez user intervention)? To zmienia target o ~10pp.

**Q2.** Reviewer subagent z binding verdictem wymaga git pre-commit
hook który może odrzucić commit. To nowa friction dla developer flow
(przy każdym commicie reviewer score). Akceptowalne?

**Q3.** `bin/sage-close` jako jedyna sanctioned ścieżka close-out
oznacza że manualny `git push` będzie wymagał albo użycia skryptu,
albo explicit override. Akceptowalne, czy wolimy soft enforcement?

**Q4.** Phase tracker wymaga dyscypliny w `phase:` frontmatter
updates. Czy ufamy agentowi że będzie advance'ować phase poprawnie,
czy advance ma robić osobny mechanizm (np. PostToolUse Bash hook
detektujący "plan.md written → advance phase: planning → implementation")?

---

## Out of scope

- Antigravity platform — ten audit tylko Codex
- Alternative AI platforms migration — non-goal
- Per-turn re-injection of full AGENTS.md — Codex limitation, nie
  addressable tutaj
- UX parity z Claude Code slash commands — explicit non-goal portu
