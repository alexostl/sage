---
cycle_id: "20260429-claude-port-logic-map"
title: "Claude Port Logic Map (current state)"
workflow: map
phase: map
status: completed
created: 2026-04-29
updated: 2026-04-30
owner: alexostl
purpose: >
  Logiczna mapa portu Claude Code jako stan obecny — wejście dla projektowania
  portu Codex. NIE jest specyfikacją Codex; opisuje co port Claude faktycznie
  robi (capabilities, odpowiedzialności, napięcia), żeby agent projektujący
  Codex rozumiał które zachowania trzeba zachować, a które są przypadkowe.
consumed_by:
  - 20260429-codex-port-rewrite  # active (design phase, ADRs 1-9 approved)
  - 20260429-codex-port-architecture-redesign  # rejected-superseded
artifacts:
  - manifest.md
  - map.md
ontology_storage: sage-memory (20 entities + 26 relations, scope: project)
notes: |
  Domknięcie 2026-04-30: dodano manifest, zaktualizowano `related:` w map.md
  na aktywny consumer (codex-port-rewrite). Mapa pozostaje read-only
  reference podczas design review (cross-check: ADR ↔ Codex docs ↔ ta mapa).
---

# Manifest — Claude Port Logic Map

Wejściowa ontologia obecnego wdrożenia Claude Code, używana jako jedno
z trzech źródeł prawdy w design review portu Codex (obok ADRów 1–9
i oficjalnej dokumentacji Codex).

Read-only podczas review. Modyfikacje tylko jeśli review wykryje
nieścisłość w samej mapie (np. capability opisany niezgodnie ze
stanem faktycznym).
