---
title: "Decision: Alex-native artifact language"
status: accepted
date: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
---

# Decision: Alex-native artifact language

## Context

Alex chce, żeby self-host Sage pisał nowe pliki dokumentacyjne w `.sage` po
polsku, bo wtedy istnieje większa szansa, że będzie czytał kluczowe fragmenty.
Jednocześnie scope ma pozostać mały: nie zmieniamy nazw frameworka ani historii.

## Decision

Nowe treści artefaktów `.sage` będą pisane po polsku, ale nazwy artefaktów,
workflowów, komend i terminów Sage pozostają po angielsku. Historyczne pliki w
`.sage/work` i `.sage/docs` nie są migrowane.

## Trade-offs

To daje szybki efekt i zachowuje zgodność z istniejącą metodologią, ale
pozostawia repo w stanie dwujęzycznym. Ten koszt jest akceptowany, bo stare
pliki są zapisem decyzji historycznych, nie materiałem do migracji.

Odrzucono globalny language config i migrację historycznych plików, bo v1 jest
self-hostowym dostrojeniem pod Alexa, nie publicznym systemem lokalizacji.

## Consequences

Build musi zmieniać future-facing instructions i templates/prompts, a nie
uruchamiać masowego tłumaczenia istniejącej dokumentacji.

Rollback oznacza cofnięcie commitów instrukcji/templates/testów. Pliki `.sage`
utworzone w międzyczasie po polsku zostają historycznymi artefaktami cykli.
