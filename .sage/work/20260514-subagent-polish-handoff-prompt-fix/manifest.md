---
cycle_id: "20260514-subagent-polish-handoff-prompt-fix"
title: "Fix: subagent handoff prompts must use Polish prose for Alex"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: false
priority: P1
source: "post-completion audit of Batch 6"
source_cycle: "20260510-subagent-self-learning-recall-fix"
tags:
  - needs-implementation
  - subagent-review
  - alex-native
  - prompt-policy
related:
  - ".sage/work/20260510-subagent-self-learning-recall-fix/manifest.md"
  - ".sage/work/20260510-subagent-self-learning-recall-fix/plan.md"
  - ".sage/work/20260510-subagent-self-learning-recall-fix/verification.md"
  - ".sage/decisions.md"
  - "core/capabilities/review/auto-review/SKILL.md"
  - "core/workflows/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
scope:
  - ".sage/work/20260514-subagent-polish-handoff-prompt-fix/*"
  - ".sage/decisions.md"
  - "core/capabilities/review/auto-review/SKILL.md"
  - "core/workflows/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: subagent handoff prompts must use Polish prose for Alex

## Finding

Po zamknięciu Batcha 6 Alex zauważył świeże zachowanie: subagent został
uruchomiony z angielskim handoff/prompt prose mimo wcześniejszego wymagania, że
prompty dla subagentów tworzone przez głównego agenta przy handoffie dla Alexa
mają być po polsku.

Audit Batcha 6 pokazał, że był tam realny fix dla approval boundary i targeted
self-learning recall, ale językowy kontrakt dla subagent handoff promptów został
zapisany tylko w artefaktach cyklu. Nie trafił do source/test surfaces, które
faktycznie instruują albo weryfikują prompt subagenta.

## Expected Behavior

Gdy główny agent uruchamia subagenta review/fix/research dla Alexa, naturalna
proza promptu/handoffu ma być po polsku.

Nie tłumaczyć canonical identifiers ani evidence:

- paths;
- command names;
- tool names;
- frontmatter keys;
- `filter_tags: ["self-learning"]`;
- quoted evidence;
- raw command output.

## Candidate Scope

- Dodać tę regułę do realnej prompt-policy surface, zwłaszcza
  `core/capabilities/review/auto-review/SKILL.md`.
- Sprawdzić, czy `core/workflows/**` albo generated Codex `AGENTS.md` powinny
  zawierać krótki pointer do polskiego subagent handoff contractu.
- Dodać regresję tekstową, która failuje, jeśli source/test surfaces mają
  targeted recall dla subagentów, ale nie mają Alex-native Polish prose
  requirement dla subagent handoff promptów.
- Upewnić się, że fix nie wymusza tłumaczenia canonical terms, paths, commands,
  tool names, frontmatter keys, quoted evidence ani raw outputów.

## Boundary

To jest osobny follow-up po Batchu 6. Batch 6 pozostaje historycznie zamknięty:
naprawił approval boundary i targeted self-learning recall, ale ten language
handoff element został wyjęty jako niezrealizowany implementation gap.
