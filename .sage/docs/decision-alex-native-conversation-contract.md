---
title: "Decision: Alex-native conversation contract"
status: accepted
date: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
---

# Decision: Alex-native conversation contract

## Context

Sage jest już skuteczny, ale czasem zakłada, że użytkownik przeczytał cały
brief/spec/plan i że może szybko przejść do implementacji. Alex chce umiarkowanej
zmiany stylu: więcej kontekstu dla junior/vibe-codera, ale bez pełnego
`grill-me everywhere`.

## Decision

W Standard+ workflowach agent ma stosować lekki kontrakt rozmowy: krótko
zarysować kontekst, nie pytać o rzeczy możliwe do sprawdzenia w repo, zadawać
jedno pytanie naraz przy niejasnościach, podawać rekomendację przy wyborach i
po checkpointach linkować do najważniejszych miejsc w zapisanych artefaktach.

## Trade-offs

Kontrakt zwiększa ilość tekstu w momentach decyzyjnych, ale powinien ograniczać
nieporozumienia i zmniejszać zależność od czytania całych plików. Ryzyko
przegadania ogranicza zasada "krótki kontekst, nie wykład".

Odrzucono pełne `grill-me everywhere`, bo Sage ma pozostać szybki. Odrzucono
nowy shared snippet/include mechanism w v1, bo istniejące `core/workflows` i
`core/capabilities` są już shared source dla długiej instrukcji.

## Consequences

Największe zmiany powinny trafić do `core/workflows`, elicitation/spec/plan
capabilities i navigatora. Porty powinny przenosić kontrakt tylko w compact
always-loaded runtime text, gdzie Codex/Claude nie dziedziczą pełnego core
automatycznie.
