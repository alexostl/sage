---
cycle_id: "20260510-cluster-d-alex-native-visibility-fix"
artifact: visibility-analysis
status: completed
created: 2026-05-10
updated: 2026-05-10
---

# Visibility analysis

## Pytanie

Chcemy, żeby Sage używał natywnej widoczności pracy Codexa, ale bez obiecywania
UI, którego Sage nie kontroluje. Trzeba rozdzielić trzy rzeczy:

- zachowanie agenta: czy agent udostępnia i aktualizuje plan;
- transport/eventy Codexa: czy klient dostaje informację o planie;
- konkretny wygląd Desktop/CLI: jak dany klient pokazuje progress.

## Oficjalne evidence

OpenAI Codex App Server dokumentuje event `turn/plan/updated`. Event zawiera
`turnId`, opcjonalne `explanation` i `plan`; każdy wpis planu ma `step` oraz
`status`, gdzie status to `pending`, `inProgress` albo `completed`.

Codex CLI slash commands dokumentują `/plan` jako tryb proszenia Codexa o plan
wykonania przed implementacją. Ta sama dokumentacja opisuje `/title` jako
konfigurację elementów tytułu terminala, w tym `task progress`.

## Wniosek

Plan/progress jest realną powierzchnią Codexa, ale Sage powinien formułować
kontrakt jako wymaganie zachowania agenta, nie jako obietnicę konkretnego UI.
Bezpieczny invariant:

- dla Standard+ work w Codex agent powinien udostępnić krótki plan 3-6 kroków;
- plan ma odzwierciedlać bieżący etap pracy i być aktualizowany po istotnych
  przejściach;
- plan UI nie zastępuje Sage artifacts, gates ani `manifest.md`;
- lekkie pytania, read-only rozmowy i krótkie statusy nie wymagają planu,
  bo wtedy plan byłby szumem.

## Ryzyko

`/plan` CLI mode nie jest tym samym co programowe `update_plan` w Codex
Desktop. Dlatego nie należy pisać w Sage, że konkretny command albo konkretna
ramka UI zawsze się pojawi. Możemy natomiast wymagać, żeby agent korzystał z
dostępnego mechanizmu plan/progress, jeśli platforma go udostępnia.

## Źródła

- https://developers.openai.com/codex/app-server#turn-events
- https://developers.openai.com/codex/cli/slash-commands#built-in-slash-commands
