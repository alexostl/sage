---
title: "Decision: Alex-native checkpoint autonomy option"
status: accepted
date: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
---

# Decision: Alex-native checkpoint autonomy option

## Context

Alex czasem chce zatwierdzać każdy etap, ale w mniej kluczowych cyklach może
chcieć pozwolić agentowi przejść od zatwierdzonego `spec` albo `plan` przez
dalsze kroki bez kolejnych zatrzymań.

## Decision

Checkpointy mogą oferować opcję autonomicznej kontynuacji jako świadomy wybór
użytkownika w danym cyklu. Domyślny tryb pozostaje checkpointed. Autonomia musi
zatrzymać się przy scope change, ryzykownej decyzji, konflikcie z dokumentacją,
awarii testów zmieniającej plan, deprecjacji publicznego zachowania albo
bezpośrednim poleceniu pauzy.

Po `spec` autonomia może przejść przez planowanie tylko wtedy, gdy plan jest
mechanicznym rozbiciem zatwierdzonego speca. Jeśli planowanie ujawnia ważne
pytanie, istotny trade-off, nową decyzję architektoniczną albo scope expansion,
agent zatrzymuje się przed implementation.

## Trade-offs

Opcja autonomiczna przyspiesza mniejsze cykle, ale może wyglądać jak osłabienie
Rule 4. Dlatego nie jest globalnym ustawieniem i musi mieć jawne stop
conditions w workflow text.

Autonomia po `plan` jest bezpieczniejszą ścieżką, bo implementation scope jest
już opisany. Autonomia po `spec` zostaje dostępna, ale z mocniejszym stopem
przed implementation.

## Consequences

Build plan powinien zmienić checkpoint option text w core workflowach i
generatorach instrukcji, a testy powinny sprawdzać zarówno istnienie opcji, jak
i obecność stop conditions.
