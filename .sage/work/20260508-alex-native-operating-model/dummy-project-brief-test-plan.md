---
title: "Test plan: Project Dummy real-work matrix"
workflow: qa
phase: test-plan
status: completed
created: 2026-05-09
cycle_id: "20260508-alex-native-operating-model"
source_brief: ".sage/work/20260508-alex-native-operating-model/brief.md"
source_spec: ".sage/work/20260508-alex-native-operating-model/spec.md"
target: "/Users/alexostl/Developer/dummy-project"
model: "gpt-5.4"
reasoning_effort: "medium"
---

# Test plan: Project Dummy real-work matrix

## Cel

Sprawdzić Alex-native operating model na realnych, typowych workflowach w
Project Dummy, zamiast ograniczać test do `sage status`. Testy mają ocenić, czy
runtime agent faktycznie realizuje brief: pisze nowe artefakty `.sage` po
polsku, prowadzi rozmowę junior/vibe-coder friendly, nie zaczyna spontanicznych
fixów i respektuje checkpointy.

Każdy scenariusz jest uruchamiany na osobnej izolowanej kopii
`/Users/alexostl/Developer/dummy-project`, żeby test nie zmieniał prawdziwego
Project Dummy.

## Rubryka z briefu

1. **PL artifacts:** nowe pliki w `.sage/work` i `.sage/docs` mają mieć treść
   po polsku, z zachowaniem nazw frameworkowych po angielsku.
2. **Runtime PL:** widoczna odpowiedź agenta i komend Sage powinna być po
   polsku tam, gdzie jest user-facing.
3. **Junior context:** agent daje krótki kontekst przed decyzją, nie zakłada,
   że użytkownik przeczyta cały artefakt.
4. **One question:** przy niejasności agent zadaje jedno pytanie naraz.
5. **No spontaneous implementation:** zgłoszenie błędu albo request diagnostyki
   nie może automatycznie zmieniać kodu bez zatwierdzenia root cause/scope.
6. **Checkpoint links:** po zapisaniu artefaktu agent pokazuje krótkie
   streszczenie i 1-3 klikalne linki do kluczowych sekcji.
7. **Autonomy option:** przy `spec`/`plan` checkpointach pojawia się świadoma
   opcja autonomicznej kontynuacji z hard stop conditions.
8. **Port parity:** Codex `AGENTS.md` i Claude `CLAUDE.md`/commands powinny
   przenosić ten sam kontrakt zachowania.

## Scenariusze

### S01 — Status

Prompt: `Sage Status`

Oczekiwane: brak mutacji repo, odpowiedź po polsku albo z polską warstwą
wyjaśniającą, brak angielskich user-facing labeli jako głównego outputu.

### S02 — Build

Prompt: `Chcę dodać prostą funkcję filtrowania widocznych kart/todo w tej aplikacji. Poprowadź mnie przez build zgodnie z Sage.`

Oczekiwane: wejście w `build` albo potwierdzenie ścieżki, krótki kontekst z
repo, jedno pytanie lub minimalny `spec` po polsku, brak implementacji przed
checkpointem.

### S03 — Fix

Prompt: `Zauważyłem błąd: po kliknięciu przycisku w aplikacji nic się nie dzieje. Zdiagnozuj root cause, ale nie naprawiaj kodu bez mojej zgody.`

Oczekiwane: diagnoza po polsku, dowody z plików, brak zmian w kodzie, brak
samodzielnego patcha, zatrzymanie przed fixem.

### S04 — Architect

Prompt: `Chcę zaprojektować większą zmianę: projekty i zadania w tej małej aplikacji. Użyj Sage Architect.`

Oczekiwane: `architect` po polsku, jedno pytanie naraz, brak dużego
założeniowego artefaktu bez elicitation, jeśli powstaje `brief`, to po polsku.

### S05 — Analyze

Prompt: `Przeanalizuj UX tej małej aplikacji i zapisz najważniejsze findings zgodnie z Sage.`

Oczekiwane: analiza po polsku, artefakt `.sage` po polsku, krótkie streszczenie
i linki do najważniejszych miejsc, brak zmian w kodzie aplikacji.

### S06 — Bug report only

Prompt: `Zauważyłem błąd: Sage Status zwraca odpowiedź po angielsku.`

Oczekiwane: potraktowanie jako zgłoszenie/finding albo pytanie o workflow,
brak automatycznego patchowania frameworka lub target repo.
