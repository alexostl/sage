---
status: accepted
created: 2026-05-14
updated: 2026-05-14
accepted_by: alexostl
accepted_at: 2026-05-14
---

# Root Cause Diagnosis

## Cause

`same_turn_bootstrapped_cycle` modeluje ryzyko zbyt płasko: jeśli w tej samej
turze i tym samym cyklu log mutacji zawiera canonical `manifest.md` albo
canonical `plan.md`, to późniejszy source/runtime/test/instruction edit jest
blokowany jako self-created approval. Predicate nie rozróżnia dwóch sytuacji:

- nielegalny bootstrap, gdzie agent tworzy manifest/plan i od razu traktuje go
  jak approval;
- legalny bookkeeping po approval, gdzie plan/scope istniał wcześniej, użytkownik
  zatwierdził przejście, a agent ma obowiązek zaktualizować manifest przed
  implementacją.

## Evidence

- `runtime/platforms/codex/hooks/pre-tool-validate.sh` sprawdza tylko
  `session_id`, `turn_id`, `cycle_id` oraz obecność `.sage/work/<cycle>/manifest.md`
  albo `.sage/work/<cycle>/plan.md` w `.sage/.session-mutations.log`.
- Ten check odpala się przed risky-path / `semantic_reclassification` handling,
  więc `semantic_reclassification: accepted` nie może pomóc, jeśli manifest był
  zmieniony w tej samej turze.
- Istniejące testy pokrywają klasyczny zakaz: same-turn manifest/plan nie może
  sam autoryzować source edit. Testy nie pokrywają pozytywnego przypadku:
  prior approved plan/scope plus same-turn manifest bookkeeping po approval.
- Ad hoc reprodukcja pokazała:
  - prior-turn manifest+plan pozwala source edit;
  - same-turn noncanonical `plan-milestone-1.md` sam pozwala source edit;
  - same-turn `manifest.md` albo canonical `plan.md` blokuje source edit, nawet
    gdy manifest ma `semantic_reclassification: accepted` i scope obejmuje
    target.

## Chain

Fix/build workflow po approval wymaga najpierw zaktualizować manifest
(`phase: deliver` albo implementation phase, scope, czasem
`semantic_reclassification: accepted`), a dopiero potem wejść w source/test
edits. Hook loguje tę wymaganą mutację jako same-turn mutation. Następnie
boundary-path edit trafia w `same_turn_bootstrapped_cycle`, który widzi tylko
"manifest/plan zmieniony w tej turze" i blokuje implementację jako
self-created approval. W kolejnej turze każdy dodatkowy wymagany manifest
checkpoint może odnowić ten sam warunek, stąd double-block pattern.

## Confidence

High.

## Scope Implication

Fix powinien pozostać minimalny, ale musi dodać brakujący model legalnego
bookkeepingu po approval. Najmniejsza sensowna powierzchnia to regresje w
`pre-tool-validate.bats` oraz doprecyzowanie predicate albo metadata contract w
`pre-tool-validate.sh`. Agent-facing guidance może być potrzebne tylko wtedy,
gdy plan pokaże, że hook nie ma dość danych, aby odróżnić legalny bookkeeping od
self-approval bez dodatkowego markera.

## Additional Workflow Requirement

Alex zdecydował, że Sage ma mieć oficjalną opcję checkpointu
`[I] Revise and Implement in the same turn`. To jest legalne tylko jako
explicit bounded conditional approval: użytkownik mówi agentowi, jakie konkretne
punkty rewizji nanieść, i jednocześnie autoryzuje implementację po tej rewizji.

To nie znosi bramek approval. Zmienia semantykę jednej bramki: approval może być
warunkowe, jeśli warunek jest konkretny i zamknięty. Agent nadal musi stopować,
gdy rewizja wymaga scope expansion, nowej decyzji, nowego ryzyka albo wykracza
poza opisane poprawki.
