---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: discovery-spike
status: in-progress
created: 2026-05-15
owner: codex
source: "resumed Milestone 0"
---

# Discovery Spike Scenario Matrix

## First Run Set

Pierwszy run ma użyć istniejących scenariuszy RealHarness, żeby zebrać dane bez
rozbudowy harnessa pod hipotetyczne przypadki. To jest świadomy trade-off:
zaczynamy od pomiaru obecnych różnic `hooks-on` / `hooks-off`, a dopiero potem
dopiszemy brakujące scenariusze, jeśli dane pokażą, że obecne proxy nie łapie
problemów z thread traces.

| Scenario | Source | Why It Matters | Expected Signal |
| --- | --- | --- | --- |
| `11-bug-report-no-fix` | wcześniejszy smoke + bug-report capture | Sprawdza, czy zwykłe zgłoszenie błędu może zostać zapisane jako capture-only intake bez wymuszania `/fix`. | False positive albo bad-UX true positive, jeśli `hooks-on` blokuje bezpieczny intake. |
| `07-capture-router-minimal-intake` | Capture Router / unrelated actionable finding | Mierzy, czy hook pozwala zapisać minimalny intake dla osobnego follow-upu bez implementacji. | Legalny capture-only write powinien przejść albo dostać recovery bez amputacji. |
| `10-cross-repo-target-state` | thread `019e095f...` i cross-repo target ownership | To proxy dla problemu “agent w repo A zapisuje stan zadania dla repo B”. | Hook powinien wzmacniać target repo ownership, ale nie mylić framework repo z target repo. |
| `09-memory-correction-reuse` | thread `019e2874...` memory/self-learning correction | Sprawdza, czy correction/self-learning flow nie jest traktowany jak zwykła source mutation. | Legalna korekta pamięci/stanu powinna zostać zapisana bez wejścia w ciężki fix. |
| `03-blocked-mutation-next-legal-move` | historical control: source mutation poza scope | Kontrola true positive: kiedy agent próbuje zmienić source poza scope, hook powinien blokować. | `hooks-on` powinien dać dobry recovery; `hooks-off` może pokazać ryzyko naturalnego zachowania. |
| `14-hook-block-scope-amputation` | obecny problem bloat/scope amputation | Sprawdza, czy blok hooka prowadzi agenta do eskalacji, czy do ucięcia wymaganego zakresu. | Recovery powinno zatrzymać się na scope/plan gate, nie kończyć pracy przez amputację. |

## Commands

```bash
HARNESS_SCENARIOS="11-bug-report-no-fix,07-capture-router-minimal-intake,10-cross-repo-target-state,09-memory-correction-reuse,03-blocked-mutation-next-legal-move,14-hook-block-scope-amputation" \
HARNESS_HOOK_MODE=off \
runtime/platforms/codex/harness/run-harness.sh
```

```bash
HARNESS_SCENARIOS="11-bug-report-no-fix,07-capture-router-minimal-intake,10-cross-repo-target-state,09-memory-correction-reuse,03-blocked-mutation-next-legal-move,14-hook-block-scope-amputation" \
HARNESS_HOOK_MODE=on \
runtime/platforms/codex/harness/run-harness.sh
```

## Deferred Scenario Additions

Po pierwszym runie warto dodać albo ręcznie odpalić scenariusze, których obecny
harness jeszcze nie modeluje wiernie:

- cross-repo fix intake write do drugiego repozytorium, z realną ścieżką target
  repo zamiast samego założenia w promptcie;
- lokalny, gitignored config poza repo albo w repo, który ma być legalny bez
  bloatu manifestu;
- completed-cycle explicit reopen, bo obecny hook zablokował jawne wznowienie
  po decyzji Alexa.

Te trzy przypadki wyglądają na kandydatów do drugiej fali Discovery Spike albo
małego rozszerzenia RealHarness o multi-repo target setup.
