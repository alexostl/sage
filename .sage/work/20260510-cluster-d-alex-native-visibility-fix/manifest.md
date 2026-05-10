---
cycle_id: "20260510-cluster-d-alex-native-visibility-fix"
title: "Fix: klaster D - Alex-native communication i widocznosc pracy"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: P1
source: "cluster-map + conversation"
classification: "Systemic fix accepted as fix"
semantic_reclassification: accepted
related:
  - ".sage/work/20260509-open-work-cluster-map/cluster-map.md"
  - ".sage/work/20260509-alex-readable-change-explanations-fix/manifest.md"
  - ".sage/work/20260509-qa-workflow-polish-report-contract/manifest.md"
  - ".sage/work/20260509-codex-task-plan-visibility-fix/manifest.md"
scope:
  - ".sage/work/20260510-cluster-d-alex-native-visibility-fix/*"
  - ".sage/decisions.md"
  - "AGENTS.md"
  - "core/constitution/sage-process.constitution.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/workflows/*.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
  - "develop/templates/qa-report-template.md"
scope_note: >
  AGENTS.md and generated AGENTS.md surfaces are in scope for verification or
  regeneration, not for duplicating the same communication wording in multiple
  places. Implementation should prefer one canonical source for hot-path
  instructions and keep workflow additions minimal.
openai_docs_checked:
  - "https://developers.openai.com/codex/app-server#turn-events"
  - "https://developers.openai.com/codex/cli/slash-commands#built-in-slash-commands"
state_override:
  reason: "Klaster A byl juz otwarty w tym worktree przed startem klastra D; w tej sesji nie bylo implementacyjnych zmian plikow dla A ani D."
  accepted_by: "alexostl"
  boundary: "Wyjatek dotyczy tylko lokalnego Sage state w worktree 75f2; nie autoryzuje cross-repo ani out-of-scope edits."
semantic_reclassification_note: >
  Approved plan explicitly includes generated instructions, workflow docs, and
  tests. Editing runtime/platforms/codex/setup/tests/** is a validation change
  for this instruction-surface fix, not an unplanned scope expansion.
---

# Fix: klaster D - Alex-native communication i widocznosc pracy

## State

**Current phase:** completed - implementacja została wykonana, targeted
verification przeszła, a RealHarness QA zostało zamknięte po triage findings.

**Next step:** brak w ramach klastra D.

## Źródłowe intake'y

- `20260509-alex-readable-change-explanations-fix`
- `20260509-qa-workflow-polish-report-contract`
- `20260509-codex-task-plan-visibility-fix`

## Zakres

Klaster D poprawia to, jak Sage komunikuje pracę Alexowi:

- findings i plany mają zaczynać od prostego wyjaśnienia skutku i przyczyny,
  a dopiero potem używać nazw technicznych, ale bez dublowania tego wzorca w
  kilku gorących instrukcjach naraz;
- nowe artefakty `.sage` generowane przez workflowy mają stosować język
  projektu: w tym repo proza po polsku, przy zachowaniu angielskich nazw
  artefaktów, frontmatter keys, statusów, workflow names, command names,
  ścieżek, identyfikatorów i raw outputów;
- Codex task-plan/progress visibility wymaga najpierw analizy: wiemy, że
  Codex App Server wystawia `turn/plan/updated`, ale trzeba ostrożnie ustalić,
  co Sage może wymagać od agenta, a co zależy od klienta Codexa.

## Poza zakresem

- zmiana nazw statusów, frontmatter keys albo artifact filenames na polski;
- zmiana semantyki workflow gate'ów;
- twarde guardraile mutacji plików;
- wymuszanie `update_plan` dla lekkich pytań lub read-only rozmów;
- cross-worktree albo cross-repo koordynacja poza tym checkoutem.

## Verification

- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` → 45/45 pass.
- `git diff --check` → pass.
- Audit: `Artifact Language Contract` obecny w 16/16 plikach
  `core/workflows/*.workflow.md`.
- Audit: brak duplikatu `impact and cause`, `technical mechanism` albo
  `plan/progress view` w `core/constitution/sage-process.constitution.md`.

## QA Closeout

Cykl QA: `.sage/work/20260510-cluster-d-realharness-qa/`.

RealHarness był uruchomiony na `gpt-5.4`, reasoning `low`, bez parametru
`service_tier`. Sam report jest czerwony, ale Alex zaakceptował closeout po
triage:

- `03-build-out-of-scope` jest adresowane przez równoległy follow-up klastra A;
- `08-safe-autofix-metadata` jest adresowane przez focused fix klastra C;
- `6a_predicate_loc` jest zaakceptowanym warningiem.
