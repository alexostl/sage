---
cycle_id: "20260509-runtime-process-reliability-patch"
title: "Plan: Patch niezawodności runtime/process"
workflow: fix
phase: plan
status: approved
created: 2026-05-09
updated: 2026-05-09
scope: systemic
review_status: revised-after-review
implementation_mode: full-autonomous-until-close
---

# Plan: Patch niezawodności runtime/process

## Scope classification

**Systemic fix.** Ten patch celowo dotyka hooków, generated instructions,
harness assertions, runtime localization tests i artefaktów workflow Sage. Jest
za szeroki na surgical fix, bo failure'y mają wspólny model procesu: lifecycle
state, intencja użytkownika i runtime guidance nie są wystarczająco mocno
połączone.

## Scope boundaries

- **In scope:** local Codex CLI/Desktop, generated Codex project config,
  generated `AGENTS.md`, Codex hooks, Codex harness, shared Sage workflow
  templates i focused Claude parity tam, gdzie zmienia się shared generated
  output.
- **Out of scope by default:** Codex Cloud runtime behavior. Jeśli ma wejść,
  wymaga osobnego smoke/audit matrix, bo cloud ma inny execution model.
- **Parked unless reopened:** `analyze` over-escalation do browser/Playwright
  dla lekkiej analizy. To zostaje jako follow-up finding poza tym patchem.
- **Kept in scope with narrower label:** copy-boundary regression zostaje jako
  harness/distribution regression, nie core runtime lifecycle failure.

## Phase split

- **Phase 1 must ship:** instruction loading/trust, hook lifecycle resolver,
  close-cycle contract, defense-in-depth audit model.
- **Phase 2 must ship:** no-spontaneous-fix real-agent harness, semantic
  harness assertions, subagent inheritance/scope check.
- **Phase 3 can defer only with explicit note:** runtime localization,
  generated artifact language snapshots, Polish prose append guidance, Claude
  parity mirrors.

## Implementation mode after plan approval

Po zatwierdzeniu planu user musi dostać dwie jawne ścieżki:

- **Checkpointed implementation:** implementować fazami i wracać z checkpointem
  po Phase 1, Phase 2, Phase 3 oraz przed close.
- **Autonomous implementation until close:** zrobić cały zatwierdzony scope bez
  kolejnych checkpointów, aż do verification/close checkpoint.

Autonomous path nie oznacza ignorowania użytkownika. Agent musi się zatrzymać i
wrócić po decyzję, jeśli pojawi się scope expansion, ważne pytanie produktowe
lub architektoniczne, conflicting instructions, test failure wymagający zmiany
założeń, ryzyko partial guardrail albo potrzeba mutacji poza approved manifest
scope.

## Files expected to change

- `runtime/platforms/codex/setup/lib/config-toml.sh`: potraktować
  `developer_instructions` jako oficjalną warstwę compact contractu do audytu,
  a nie tylko awaryjny dodatek; dodać coverage zgodne z `AGENTS.md`.
- `runtime/platforms/codex/hooks/lib/active_init.sh`: dodać albo wesprzeć
  nowe API resolvera, np. `resolve_cycle_for_patch`, zamiast zmieniać semantykę
  legacy `active_init_path`.
- `runtime/platforms/codex/hooks/lib/bootstrap_check.sh`: rozszerzyć bootstrap
  detection tak, żeby nowy cykl mógł powstać przy innym active cycle, gdy patch
  jest wąsko ograniczony do new-cycle bootstrap/capture paths.
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`: użyć cycle resolver,
  odróżnić capture-only parked-intake updates od implementation changes i
  blokować ambiguous multi-cycle mutations z user-visible selection message.
- `runtime/platforms/codex/hooks/post-tool-check.sh`: dodać manifest completion
  status-flip audit evidence oraz close-order incidents zgodne z nowym
  contract.
- `runtime/platforms/codex/hooks/tests/*.bats`: dodać failing regression tests
  przed zmianami implementacji hooków.
- `runtime/platforms/codex/setup/lib/agents-md.sh`: wzmocnić generated Codex
  guidance dla bug-report capture/diagnosis, parked-cycle semantics, memory
  tool discovery przed filesystem fallback, Alex-native runtime expectations i
  twardego egzekwowania polskiej prozy w nowych dopiskach `.sage`.
- `runtime/platforms/codex/setup/tests/*.bats`: dodać string/snapshot
  assertions dla no-spontaneous-fix guidance, memory fallback guidance,
  status/runtime language i generated artifact heading language.
- `core/workflows/**`, `core/capabilities/**`, `develop/templates/**`: zmienić
  realne źródła generated artifact prose/headings, które dziś produkują
  angielskie sekcje typu `State`, `Context summary`, `Tasks`,
  `Next agent should`, `Spec for...`.
- `runtime/platforms/codex/harness/**`: dodać semantic state assertions i
  skalibrować obsolete signals, np. `7_l1_bypass`; dodać prompt
  `bug-report-no-fix` i checkpoint harness.
- `runtime/platforms/claude-code/**` and
  `tools/sage-claude-plugin/scripts/sage`: aktualizować parity surfaces tylko
  tam, gdzie Codex fix zmienia shared Alex-native albo lifecycle guidance, które
  Claude też eksponuje.
- `bin/sage`: localize albo route `status`/help/runtime output dopiero po tym,
  jak runtime-surface inventory wskaże konkretne strings.
- `.sage/work/20260509-runtime-process-reliability-patch/*`,
  `.sage/decisions.md` and absorbed intake manifests: śledzić approved scope,
  decisions, verification, folded-cycle status i polską nową prozę nawet przy
  dopiskach do starszych angielskich artefaktów.

## Tasks

- [x] **Task 0: Verify instruction loading and trust.**
  Dodać pre-implementation audit/test dla realnego ładowania `AGENTS.md`,
  `.codex/config.toml`, `developer_instructions`, hooks i trusted project
  state. Sprawdzić new-session behavior, `project_doc_max_bytes`/32 KiB limit
  oraz czy compact contract nie wypada z instruction chain. Wynik ma jasno
  powiedzieć, czy `developer_instructions` jest required layer dla
  Alex-native compact contractu.

- [x] **Task 1: Write failing hook lifecycle tests.**
  Pokryć:
  - new `.sage/work/<new-cycle>/manifest.md` bootstrap, gdy inny cykl jest
    `in-progress`;
  - path-intent wybiera dotknięty cykl zamiast newest active cycle;
  - ambiguous patches dotykające kilku cykli blokują się z explicit selection;
  - capture-only updates do parked intake manifests są wąsko dopuszczone z audit
    evidence albo blokowane z clear resume guidance;
  - implementation files nadal wymagają approved active scope.

- [x] **Task 2: Implement intent-aware cycle resolution.**
  Dodać nowe API hooków, np.
  `resolve_cycle_for_patch "$cwd" "${claimed_paths[@]}"`, które wyprowadza
  candidate cycle z claimed patch paths przed fallbackiem do newest active
  cycle. `active_init_path` zostawić jako legacy fallback. Zachować fail-closed
  behavior dla ambiguous implementation mutations.

- [x] **Task 3: Define close-cycle contract and audit.**
  Wybrać i zaimplementować close behavior:
  - preferred: status flip do `completed` jest domyślnie final mutation;
  - allowed exception: wąski same-cycle documentation epilogue z explicit
    marker/audit evidence.
  Plan musi zdecydować, czy cross-cycle/implementation epilogues są tylko
  post-mutation critical incidents, czy dodajemy pre-tool parser treści patcha,
  który wykrywa `status: completed` przed mutacją. Dopiero wtedy dodać tests.

- [x] **Task 3.5: Define defense-in-depth enforcement model.**
  Spisać i przetestować, co blokuje `PreToolUse`, co loguje `PostToolUse`, co
  sprawdza `Stop`/turn audit, a co weryfikuje harness przez końcowy `git diff`
  i state repo. Uwzględnić `apply_patch`, shell/Bash/unified exec, MCP/app
  tool paths i ścieżki, których hooki nie przechwytują deterministycznie.

- [x] **Task 4: Strengthen no-spontaneous-fix guardrail.**
  Zaktualizować generated guidance tak, żeby bug reports, findings i
  observations domyślnie prowadziły do capture/diagnosis, nie code edits.
  Dodać blocker prompt `bug-report-no-fix` i rubric: bez explicit fix mandate
  albo approved workflow gate nie wolno mutować `src/**`, `tests/**`,
  `bin/sage`, `runtime/**`. Wording implementation ma mówić “detect and
  regress real agent behavior”, chyba że osobny prompt-intent channel zostanie
  zaprojektowany i zatwierdzony.

- [x] **Task 4.5: Cover subagents and reviewer paths.**
  Sprawdzić, czy spawned subagents/reviewer dziedziczą `AGENTS.md`,
  `developer_instructions`, hooks i MCP/tool availability, oraz czy ich edits
  są objęte tym samym manifest scope enforcement. Jeśli Codex runtime nie daje
  prostego deterministic testu, zapisać boundary i dodać harness/audit check.

- [x] **Task 4.6: Add post-plan implementation mode choice.**
  Wygenerowane workflow/guidance ma po approved plan checkpoint pokazywać dwie
  opcje: checkpointed implementation albo autonomous implementation until
  close. Druga opcja pozwala agentowi zrobić cały approved scope bez
  checkpointów pośrednich, ale wymaga stopu przy scope expansion, important
  open question, conflicting instructions, failing tests requiring user
  decision, partial-guardrail risk albo wyjściu poza approved manifest scope.

- [x] **Task 5: Runtime localization inventory and focused fixes.**
  Zrobić inventory user-facing runtime surfaces i przed kodem uzupełnić tabelę:

  | Surface | Expected Polish prose/label | Source file | Test file | Scope |
  |---|---|---|---|---|
  | `sage status` labels | do ustalenia w inventory | `bin/sage` | `runtime/platforms/codex/setup/tests/status.bats` | must |
  | `sage doctor` labels | do ustalenia w inventory | `bin/sage` | `runtime/platforms/codex/setup/tests/doctor.bats` | must/defer |
  | hook messages | do ustalenia w inventory | `runtime/platforms/codex/hooks/**` | `runtime/platforms/codex/hooks/tests/**` | must |
  | Codex `AGENTS.md` compact contract | prose po polsku, structure/canonical terms po angielsku | `runtime/platforms/codex/setup/lib/agents-md.sh` | `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` | must |
  | Codex `developer_instructions` | compact contract zgodny z `AGENTS.md` | `runtime/platforms/codex/setup/lib/config-toml.sh` | `runtime/platforms/codex/setup/tests/stage4-config-toml.bats` | must |
  | Claude parity commands | tylko shared output, który zmienia Codex patch | `runtime/platforms/claude-code/**` | `runtime/platforms/claude-code/setup/tests/**` | can defer |

  Generated artifact templates są poza Task 5; należą do Task 6/6.5.

- [x] **Task 6: Artifact language regression coverage.**
  Dodać focused tests, które łapią English template headings/labels takie jak
  `State`, `Context summary`, `Tasks`, `Tests`, `Risks`, `Key decisions`,
  `Next agent should`, `Spec for...` i `Fix Plan for...` w generated
  `brief/spec/plan/manifest/decisions` output, chyba że są explicit canonical.
  Testy muszą wskazywać realne źródła outputu w `core/workflows/**`,
  `core/capabilities/**`, `develop/templates/**` oraz generated Codex/Claude
  mirrors.

- [x] **Task 6.5: Mocne egzekwowanie polskiej prozy w nowych dopiskach `.sage`.**
  W generated guidance i testach egzekwować, że każda nowa sekcja prozy
  dopisywana do `.sage/work`, `.sage/docs`, `.sage/decisions.md`, manifests,
  plans, specs, reports i handoffs jest po polsku. To obowiązuje nawet wtedy,
  gdy istniejący plik jest głównie po angielsku; po angielsku mogą zostać tylko
  frontmatter keys, file paths, command names, code identifiers, quoted
  evidence oraz kanoniczne terminy Sage/programistyczne.

- [x] **Task 7: Harness semantic assertions and metric calibration.**
  Rozszerzyć harness checks poza `codex exec` success:
  - read-only prompts nie zostawiają workflow state;
  - capture prompts tworzą intake manifests z `needs-triage`;
  - safe auto-fix zapisuje `.sage/.auto-fixes.log`;
  - cross-repo prompts wskazują active repo jako owner;
  - `bug-report-no-fix` nie mutuje implementation files;
  - checkpoint harness dochodzi do `spec`/`plan` checkpointu i sprawdza links,
    autonomy option oraz stop conditions;
  - `7_l1_bypass` pasuje do current mutation/log behavior albo zostaje
    zastąpiony.

- [x] **Task 8: Memory fallback and copy-boundary regressions.**
  Zaktualizować Codex guidance, żeby używał dostępnej Codex tool-discovery
  surface dla Sage Memory/MCP przed `.sage-memory/*.md` fallback. W Codex
  Desktop może to być `tool_search`; w CLI/app-server trzeba weryfikować przez
  dostępne MCP status/tool surfaces albo configured MCP tools. Dodać
  copy-boundary coverage jako harness/distribution regression, żeby historyczne
  QA/nested `target/sage` outputs nie mogły wejść do przyszłych framework
  distribution copies.

- [x] **Task 9: Fold absorbed manifests and verify.**
  Oznaczyć absorbed intake/follow-up manifests jako folded into this cycle,
  uruchomić focused Bats suites i diff checks, potem zapisać completion
  evidence.

## Verification plan

- `bats runtime/platforms/codex/hooks/tests`
- `bats runtime/platforms/codex/setup/tests`
- `bats runtime/platforms/codex/harness/tests`
- `bats runtime/platforms/claude-code/setup/tests`
- `git diff --check`

Jeśli runtime localization zmieni `bin/sage`, dodać focused `status`/`doctor`
test command używany przez istniejące setup tests.

## Rollback

Wszystkie zmiany są ordinary git changes. Revert patch commit przywraca
poprzednie hook/runtime behavior. Jeśli subpart okaże się zbyt ryzykowny w
implementacji, zostawić failing test i przenieść ten subpart z powrotem do
intake manifest zamiast po cichu shipować częściowy guardrail.

## Approval checkpoint

Sage: Fix scope is **Systemic**.

**Approved by Alex:** `[F] Full autonomous implementation`.

After approval:

[C] Checkpointed implementation — phase checkpoints before close
[F] Full autonomous implementation — no intermediate checkpoints unless blocked

## Completion evidence

Wykonano pełny approved scope w trybie `[F]`. Najważniejsze efekty:

- intent-aware cycle resolver i testy dla bootstrap, path-intent, ambiguous
  multi-cycle oraz parked capture;
- close-cycle `post_completion_mutation` audit i testy;
- no-spontaneous-fix guidance oraz real-agent harness blocker z
  `forbidden_changed_patterns`;
- Codex/Claude generated guidance dla polskiej prozy, memory discovery,
  subagents i trybów `[C]`/`[F]`;
- runtime localization dla `sage status` i wybranych `sage doctor` komunikatów;
- absorbed manifests oznaczone jako folded into this cycle.

Verification:

- `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests runtime/platforms/codex/harness/tests runtime/platforms/claude-code/setup/tests`
  → `1..317`, wszystkie testy przeszły.
- `bats runtime/platforms/claude-code/setup/tests/generate-claude-code.bats`
  → `1..2`, wszystkie testy przeszły.
