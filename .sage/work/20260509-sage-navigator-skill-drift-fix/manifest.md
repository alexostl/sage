---
cycle_id: "20260509-sage-navigator-skill-drift-fix"
title: "Fix: drift wystawionego sage-navigator skilla"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
priority: P2
source: "conversation"
suggested_workflow: fix
related:
  - ".agents/skills/sage-navigator/SKILL.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage7-skills.bats"
---

# Fix: drift wystawionego sage-navigator skilla

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w osobny `/sage:fix`, ustalić source-of-truth dla
`sage-navigator` na powierzchni Codex i dodać regresję, żeby wystawiony skill
nie zostawał starszą kopią.

## Finding

Podczas rozmowy o tym, czy ubogie `description` w loader stubach osłabia routing
workflow, porównanie plików pokazało drift:

- źródło navigatora: `core/capabilities/orchestration/sage-navigator/SKILL.md`;
- wystawiony skill: `.agents/skills/sage-navigator/SKILL.md`;
- wystawiona kopia nie zawiera najnowszego `Alex-native operating contract` i
  różni się od source-of-truth.

To jest mały, ale realny problem instruction reachability. `AGENTS.md` instruuje
agenta, żeby dla ambiguous Standard+ work startował z router/navigator skill,
więc navigator musi być świeży na powierzchni, którą Codex faktycznie widzi.

## Desired behavior

`sage update` powinien deterministycznie wystawiać aktualny `sage-navigator`
albo jako pełną kopię z source-of-truth, albo jako loader stub z poprawną
ścieżką do `sage/core/capabilities/orchestration/sage-navigator/SKILL.md`.

## Candidate scope

- Zdiagnozować, dlaczego `.agents/skills/sage-navigator/SKILL.md` nie jest
  odtwarzany z aktualnego source-of-truth.
- Ustalić czy navigator ma być direct skill copy, czy loader stub.
- Dodać test regresyjny, który wykrywa drift między source-of-truth i
  wystawionym Codex skillem.
- Uruchomić `bin/sage update` albo odpowiedni Stage 7 test po poprawce.

## Boundary

Ten intake nie zmienia jeszcze architektury loader stubów workflow. UI po slash
może nadal pokazywać krótkie opisy. Problem dotyczy świeżości i reachability
samego `sage-navigator`.
