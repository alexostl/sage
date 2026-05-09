---
cycle_id: "20260509-runtime-process-reliability-patch"
title: "Patch niezawodności runtime/process"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
scope_class: systemic
semantic_reclassification: accepted
review_status: revised-after-review
implementation_mode: full-autonomous-until-close
plan_approval: approved
absorbs:
  - "20260507-codex-close-cycle-epilogue-fix"
  - "20260507-codex-v11-harness-audit-followups"
  - "20260507-hook-hardblock-confirmation-capture"
  - "20260508-alex-native-operating-model"
  - "20260509-hook-cycle-selection-capture"
  - "20260509-manifest-completion-audit-capture"
scope:
  - ".sage/work/20260509-runtime-process-reliability-patch/*"
  - ".sage/work/20260507-codex-close-cycle-epilogue-fix/manifest.md"
  - ".sage/work/20260507-codex-v11-harness-audit-followups/manifest.md"
  - ".sage/work/20260507-hook-hardblock-confirmation-capture/manifest.md"
  - ".sage/work/20260508-alex-native-operating-model/manifest.md"
  - ".sage/work/20260508-alex-native-operating-model/real-use-findings.md"
  - ".sage/work/20260509-hook-cycle-selection-capture/manifest.md"
  - ".sage/work/20260509-manifest-completion-audit-capture/manifest.md"
  - ".sage/decisions.md"
  - "core/**"
  - "develop/templates/**"
  - "bin/sage"
  - "tools/sage-claude-plugin/scripts/sage"
  - "runtime/platforms/codex/**"
  - "runtime/platforms/claude-code/**"
  - ".github/workflows/*"
---

# Patch niezawodności runtime/process

## State

**Current phase:** deliver — plan został zrewidowany po extensive review,
zatwierdzony przez Alexa, a tryb implementacji ustawiono na
`full-autonomous-until-close`.

**Next step:** realizować approved scope bez checkpointów pośrednich aż do
verification/close, chyba że pojawi się scope expansion, ważny blocker,
conflicting instructions albo ryzyko partial guardrail.

## Scalony problem

Kilka otwartych cykli intake/follow-up wskazuje na tę samą lukę: local Codex
CLI/Desktop runtime Sage wyprowadza workflow state zbyt wąsko z
"newest in-progress manifest" i z instrukcji tekstowych, a realna praca
potrzebuje defense-in-depth model świadomego intencji, który rozróżnia:

- bootstrap nowego cyklu od out-of-scope mutation;
- capture-only intake updates od zmian implementacyjnych;
- completion manifestu od zwykłych edycji;
- bug reporty/findingi od zatwierdzonego przez użytkownika mandatu na
  implementację;
- język generowanych artefaktów od języka runtime/CLI/status;
- to, co hook może deterministycznie zablokować, od tego, co musi wykryć
  harness/audit po całym turnie.

## Wciągnięte otwarte cykle

- `20260507-codex-close-cycle-epilogue-fix`: close status flip może zablokować
  końcowy same-cycle epilogue/documentation mutation.
- `20260507-codex-v11-harness-audit-followups`: harness potrzebuje semantic
  assertions, lepszych metrics, memory fallback guidance, copy-boundary coverage
  i decyzji sprzęgniętych z capture intake.
- `20260507-hook-hardblock-confirmation-capture`: hard fail-closed hook blocks
  mogą uwięzić explicit user-requested documentation/intake capture zamiast
  zaoferować wąską audited recovery path.
- `20260508-alex-native-operating-model`: real-use validation ujawniło English
  runtime surfaces, spontaniczne code edits po bug report, niepełne
  checkpoint/autonomy coverage i artifact heading leakage.
- `20260509-hook-cycle-selection-capture`: wybór newest-active-cycle może
  zablokować legalny bootstrap nowego workflow, gdy istnieje inny
  in-progress cycle.
- `20260509-manifest-completion-audit-capture`: workflow open/close semantics
  potrzebują konkretnego manifest-driven audit point i jaśniejszych reguł dla
  parked cycles.

## Working diagnosis

Root cause jest systemowy, nie jest jednym zepsutym commandem:

1. `active_init_path` wybiera globalnie newest in-progress cycle, a
   `pre-tool-validate.sh` używa tego jako active context zanim rozważy patch
   intent, gdy istnieje aktywny cykl.
2. `bootstrap_cycle_id` obsługuje tylko no-active-cycle chicken-egg case, więc
   nie potrafi autoryzować legalnego new-cycle bootstrap, gdy inny cykl jest
   active.
3. Close/finalization checks są głównie post-mutation incidents, a nie jawnym
   status-flip lifecycle audit z ordering guidance.
4. Generated guidance nie robi z "bug report/finding is not approval to patch"
   reguły wystarczająco mocnej i testowalnej dla realnego zachowania Codex
   agenta.
5. Alex-native coverage skupił się na templates i compact instructions, ale
   nie zinwentaryzował i nie przetestował wszystkich user-facing runtime
   surfaces.
6. Language enforcement dla artefaktów `.sage` jest za słaby: agent może
   kontynuować po angielsku, gdy źródłowy plik albo wcześniejszy kontekst jest
   po angielsku. Nowe dopiski muszą być po polsku nawet w istniejących
   angielskich plikach, z wyjątkiem frontmatter keys, ścieżek, komend i
   kanonicznych terminów Sage/programistycznych.
7. Plan przed review nie rozróżniał wystarczająco: local Codex CLI/Desktop vs
   Codex Cloud; hook guardrail vs pełny enforcement; main agent vs spawned
   subagents; runtime output vs generated artifact prose.

## Done criteria

- Instruction loading jest zweryfikowane dla `AGENTS.md`,
  `.codex/config.toml`, `developer_instructions`, trust state,
  `project_doc_max_bytes` i new-session behavior.
- Hook lifecycle tests obejmują new-cycle bootstrap przy innym active cycle,
  same-cycle close epilogue, capture-only parked intake updates, ambiguous
  multi-cycle patches i blokowanie implementation files.
- Plan i implementacja jasno mówią, które przypadki są blokowane przez
  `PreToolUse`, które są tylko auditowane przez `PostToolUse`/`Stop`, a które
  muszą być wykrywane przez harness po całym turnie.
- Runtime guidance i harness regression wykrywają plain bug/finding reports,
  które mutują kod bez explicit fix mandate albo approved workflow gate. Jeśli
  ma to być twardy block, patch musi dodać osobny prompt-intent channel.
- Po zaakceptowanym planie użytkownik ma dwie jawne ścieżki implementacji:
  checkpointed implementation albo autonomous implementation until close.
  Autonomous path nadal zatrzymuje się przy scope expansion, ważnym pytaniu,
  conflicting instructions, failing tests wymagających decyzji użytkownika albo
  ryzyku partial guardrail.
- Subagents/multi-agent behavior ma test albo documented boundary: instruction
  inheritance, MCP/tool availability, hooks i manifest scope enforcement.
- Alex-native runtime surfaces mają inventory i focused assertions dla
  status/help/workflow-facing output, który powinien być po polsku.
- Generated artifact snapshot/string tests łapią English headings i handoff
  labels w przyszłym output `brief/spec/plan/manifest/decisions`, gdy te labelki
  nie są canonical Sage terms.
- Nowa proza w `.sage` jest mocno egzekwowana jako polska, także w dopiskach do
  starszych angielskich artefaktów; tests/guidance pozwalają na angielski tylko
  dla frontmatter keys, command names, code paths, quoted evidence i
  kanonicznych technical terms.
- Harness signals sprawdzają resulting repository state, nie tylko successful
  `codex exec` exit status.
- Istniejące absorbed intake manifests zostają oznaczone jako folded into this
  cycle po zatwierdzeniu implementation scope.
- Scope boundary jest jawny: ten patch dotyczy local Codex CLI/Desktop;
  Codex Cloud jest out-of-scope, chyba że dostanie osobny smoke/audit matrix.

## Implementation evidence

Patch zrealizował zatwierdzony scope dla local Codex CLI/Desktop:

- hook resolver wybiera cykl po intencji patcha, pozwala na wąski bootstrap
  nowego cyklu przy innym active cycle, rozróżnia parked capture i blokuje
  ambiguous multi-cycle mutations;
- close-cycle audit loguje `post_completion_mutation` jako critical incident,
  z wąskim markerem `closeout_epilogue` dla jawnego wyjątku;
- generated Codex i Claude guidance wzmacnia memory discovery, no-spontaneous
  fix, polską prozę w nowych dopiskach `.sage`, tryby `[C]`/`[F]` po planie
  oraz dziedziczenie scope przez subagents/reviewer agents;
- harness dostał release-blocker `bug-report-no-fix` i semantic check
  `forbidden_changed_patterns`, żeby wykrywać implementacyjne mutacje po samym
  zgłoszeniu błędu;
- `sage status` i wybrane `sage doctor` runtime labels zostały spolszczone z
  regresją w Bats;
- absorbed intake/follow-up manifests zostały oznaczone jako folded into this
  cycle.

Verification:

- `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests runtime/platforms/codex/harness/tests runtime/platforms/claude-code/setup/tests`
  → `1..317`, wszystkie testy przeszły.
- `bats runtime/platforms/claude-code/setup/tests/generate-claude-code.bats`
  → `1..2`, wszystkie testy przeszły po parity update.
