---
cycle_id: "20260510-subagent-review-approval-boundary-fix"
title: "Fix: subagent review nie może automatycznie zatwierdzać implementacji"
workflow: fix
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: P1
source_cycle: "20260509-workflow-entry-resume-recovery-autonomy-fix"
tags:
  - needs-triage
  - checkpoint
  - subagent-review
related:
  - "core/workflows/fix.workflow.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
---

# Fix: subagent review nie może automatycznie zatwierdzać implementacji

## Finding

Podczas plan gate dla Klastra B opcja:

`[A] Subagent review — explicitly authorize Codex to spawn a read-only subagent to review the fix plan, then implement`

okazała się błędnie sformułowana. Agent potraktował `then implement` jako zgodę
na wejście w implementation po subagent review. To jest ryzykowne, szczególnie
gdy review zwraca `approve with changes`.

## Expected Behavior

Subagent review jest pogłębioną analizą, a nie approvalem użytkownika.

Poprawny flow:

1. User wybiera `[A] Subagent review`.
2. Agent uruchamia read-only subagenta.
3. Agent pokazuje wynik review i poprawiony plan/root cause.
4. User dostaje kolejny checkpoint i dopiero jawnie zatwierdza implementację.

Wyjątkiem może być osobna, wyraźna opcja typu "subagent review, and if clean,
continue", ale obecne gate wording nie powinno tego sugerować.

## Why It Matters

Review może ujawnić zmianę scope, ryzyko albo korektę planu. W takim przypadku
implementacja bez ponownego checkpointu omija człowieka dokładnie wtedy, kiedy
pojawiła się nowa informacja.

## Candidate Scope

- Poprawić wording `[A] Subagent review` w build/fix/architect gates.
- Usunąć albo rozdzielić frazę `then implement`.
- Dodać zasadę: `approve with changes` po subagent review wraca do usera.
- Dodać test generated guidance, jeśli ten wording jest generowany do Codex
  `AGENTS.md`.

## Boundary

Capture-only. Ten intake nie jest częścią obecnej implementacji Klastra B,
chyba że Alex później jawnie zdecyduje, że ma zostać włączony do scope.
