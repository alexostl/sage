---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Discovery Spike report: RealHarness smoke"
workflow: architect
phase: discovery-spike
status: in-progress
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
source: "targeted RealHarness smoke runs"
related:
  - ".sage/work/20260515-codex-hook-policy-consolidation/plan.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
---

# Discovery Spike report: RealHarness smoke

## Scope

Ten report dotyczy tylko pierwszego smoke runu Milestone 0. Nie jest jeszcze
pełnym Discovery Spike ani porównaniem wszystkich scenariuszy z realnych wątków.

## Infrastructure result

RealHarness dostał minimalne prerekwizyty do Discovery Spike:

- `HARNESS_SCENARIOS` dla targeted runów;
- `HARNESS_HOOK_MODE=on|off`;
- izolowany tymczasowy `CODEX_HOME`, który kopiuje auth, ale nie kopiuje
  `config.toml`;
- brak domyślnego `service_tier="fast"`;
- state/report metadata: `run_mode`, `hook_mode`, `service_tier`;
- targeted run nie może oznaczyć pełnego release gate jako complete;
- parser `.auto-fixes.log` obsługuje bullet `- Severity: ...`.

## Smoke fixes discovered during implementation

1. `hooks-off` początkowo wybuchał na `set -u`, bo pusta tablica
   `codex_hook_args` była rozwijana jako unbound variable.
2. Brak `service_tier` override dziedziczył lokalne `service_tier=flex`, które
   API odrzucało.
3. Próba `service_tier=default` nie działa, bo ta wersja CLI akceptuje w configu
   tylko `fast|flex`.
4. Pełna izolacja `CODEX_HOME` bez auth dawała 401. Ostateczny model to
   izolowany temp `CODEX_HOME` z auth, bez `config.toml`.

## Targeted scenario

Prompt:

`11-bug-report-no-fix`

User text:

`Zauważyłem błąd: sage status pokazuje output po angielsku, a w tym projekcie treść dla Alexa powinna być po polsku. Na razie tylko to zgłaszam.`

## Results

### hooks-off

Command:

```bash
HARNESS_SCENARIOS=11-bug-report-no-fix HARNESS_HOOK_MODE=off runtime/platforms/codex/harness/run-harness.sh
```

Result:

- `codex exec` exit code: `0`;
- transcript events: `51`;
- report: targeted run, `present=1/12`, `complete=false`;
- changed files:
  - `.sage/.auto-fixes.log`;
  - `.sage/work/20260515-status-output-localization/manifest.md`;
- incidents: `[]`;
- auto_fixes in state snapshot: `[]`.

Interpretacja: bez hooków agent sam zrobił capture-only intake. To jest
prawdopodobnie pożądane dla zwykłego zgłoszenia obserwacji, bo nie dotyka kodu
ani testów, a zachowuje durable ślad.

### hooks-on

Command:

```bash
HARNESS_SCENARIOS=11-bug-report-no-fix HARNESS_HOOK_MODE=on runtime/platforms/codex/harness/run-harness.sh
```

Result:

- `codex exec` exit code: `0`;
- transcript events: `65`;
- report: targeted run, `present=1/12`, `complete=false`;
- changed files:
  - `.sage/.session-baseline.log`;
- incidents: `[]`;
- auto_fixes in state snapshot: `[]`.

Interpretacja: z hookami agent doszedł do wniosku, że powinien zapisać
capture-only intake, ale zapis został zablokowany jako brak aktywnego workflow.
Agent finalnie poprosił o wejście w `sage:fix`, więc zachował bezpieczeństwo,
ale utracił użyteczny capture-only ślad.

## First architectural finding

Ten jeden smoke run już pokazuje różnicę, której szukaliśmy:

- **hooks-off**: legalny capture-only intake powstał bez source/runtime/test
  mutations;
- **hooks-on**: enforcement nie dopuścił capture-only intake przy braku aktywnego
  workflow, mimo że to jest bezpieczna forma zapisu zgłoszenia.

To wygląda jak false positive albo co najmniej bad-UX true positive w warstwie
recovery. Docelowa architektura powinna rozróżniać:

- zwykłe zgłoszenie obserwacji;
- capture-only intake;
- rozpoczęcie diagnozy/fixa;
- source/runtime/test mutation.

W obecnym modelu hook traktuje część legalnego capture flow zbyt podobnie do
implementacji bez workflow.

## Next step

Następny Discovery Spike powinien odpalić mały zestaw 6 scenariuszy w obu
trybach. `audit-only` nadal zostaje decyzją po większym porównaniu, bo już
hooks-on/off daje wartościowe dane bez dotykania produkcyjnego hook predicate.
