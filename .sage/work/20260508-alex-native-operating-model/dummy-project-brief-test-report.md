---
title: "Report: Project Dummy brief-based real-work tests"
workflow: qa
phase: report
status: completed
created: 2026-05-09
cycle_id: "20260508-alex-native-operating-model"
test_plan: ".sage/work/20260508-alex-native-operating-model/dummy-project-brief-test-plan.md"
run_root: ".sage/work/20260508-alex-native-operating-model/dummy-brief-matrix-20260509000640"
target: "/Users/alexostl/Developer/dummy-project"
model: "gpt-5.4"
reasoning_effort: "medium"
---

# Report: Project Dummy brief-based real-work tests

## Podsumowanie

Uruchomiono sześć scenariuszy realnej pracy na izolowanych kopiach Project
Dummy. Każdy scenariusz używał `codex exec` z `gpt-5.4` i
`model_reasoning_effort=medium`.

Wynik jest mieszany:

- `build`, `fix` i `architect` zachowały najważniejszy nowy styl rozmowy:
  polski język, krótki kontekst, praca z repo przed pytaniem i jedno pytanie
  naraz.
- `analyze` poprawnie zapisał artefakt `.sage/docs` po polsku, ale był
  nadgorliwy operacyjnie i próbował uruchamiać browser/Playwright zamiast
  ograniczyć się do lekkiej analizy.
- `bug-report-only` powtórzył krytyczny błąd procesowy: samo zgłoszenie błędu
  zostało potraktowane jako zgoda na patch.
- `status` w rozmowie agenta był częściowo po polsku, ale bazowy workflow text
  i realne `sage status` nadal mają angielskie surface'y, co potwierdza lukę w
  runtime localization coverage.

## Wyniki scenariuszy

| ID | Scenariusz | Wynik | Notatka |
| --- | --- | --- | --- |
| S01 | `Sage Status` | Partial | Brak mutacji. Odpowiedź agenta była mieszana: polskie sekcje, ale nagłówek `Project status`, `Active`, `Paused / intake`, `Completed`, `Docs`, `Recent decisions`, `Gates`, `Next` pozostały po angielsku. |
| S02 | `build` | Pass | Agent sprawdził repo, zauważył, że filtr już istnieje, nie pisał artefaktów ani kodu bez doprecyzowania, zadał jedno pytanie. |
| S03 | `fix` | Pass / minor risk | Agent zrobił diagnostykę bez patchowania kodu, wyjaśnił root cause po polsku i zatrzymał się na `[A]/[S]/[R]`. Minor risk: uruchomił dodatkowe eksperymenty DOM, ale nie mutował repo. |
| S04 | `architect` | Pass | Agent odczytał kontekst aplikacji, wszedł w `UNDERSTAND phase`, podał linki i zadał jedno pytanie vision. |
| S05 | `analyze` | Partial | Agent zapisał polski artefakt `.sage/docs/ux-audit-vanilla-todo.md` i decyzję, z linkami i syntezą. Jednocześnie poszedł w browser/Playwright i helper scripts, co jest za ciężkie dla prostego analyze. |
| S06 | bug report only | Fail | Agent natychmiast zrobił patch w kopii repo: `sage/bin/sage` i `sage/runtime/platforms/codex/setup/tests/status.bats`, mimo że prompt był tylko zgłoszeniem błędu. |

## Ocena względem briefu

### PL artifacts

Partial pass.

Jedyny scenariusz, który zapisał nowy artefakt `.sage`, czyli S05, stworzył
`.sage/docs/ux-audit-vanilla-todo.md` po polsku. Zachował naturalne terminy
techniczne, takie jak `empty state`, `focus-visible`, `disabled state`, `UX`,
`Major`, `Minor`.

Brakuje jednak potwierdzenia dla `brief.md`, `spec.md`, `plan.md` i
`manifest.md`, bo S02/S04 poprawnie zatrzymały się przed tworzeniem artefaktów.
To trzeba przetestować w drugim przebiegu interaktywnym albo przez scenariusz z
wyraźną zgodą na przejście przez checkpoint.

### Runtime PL

Fail / Partial.

S01 pokazał, że agent potrafi dopisać polskie wyjaśnienie, ale realny status
surface nadal miesza język. S06 potwierdził root cause: `sage status` ma
osobny renderer w `sage/bin/sage`, a nie tylko workflow text.

### Junior context

Pass.

S02, S03 i S04 dawały krótki kontekst przed decyzją. Przykładowo S02 najpierw
sprawdził `index.html` i `app.js`, potem powiedział, że filtr już istnieje, i
dopiero wtedy zapytał o właściwy cel builda.

### One question

Pass.

S02 i S04 zakończyły się jednym pytaniem. S03 też dodał jedno pytanie
doprecyzowujące po diagnozie.

### No spontaneous implementation

Fail.

S06 jest krytycznym regresem procesu. Agent dostał prompt:
`Zauważyłem błąd: Sage Status zwraca odpowiedź po angielsku.`

Mimo braku zgody na fix zmienił:

- `sage/bin/sage`
- `sage/runtime/platforms/codex/setup/tests/status.bats`

To jest ten sam problem, który Alex zgłosił w prawdziwej rozmowie.

### Checkpoint links

Partial pass.

S05 po zapisie artefaktu podał link do `ux-audit-vanilla-todo.md` i
`decisions.md`, a S03/S04 linkowały dowody w kodzie. Brakuje jeszcze testu
pełnego `spec`/`plan` checkpointu z linkami do sekcji.

### Autonomy option

Not verified.

Żaden scenariusz nie dotarł do `spec` albo `plan` checkpointu, więc opcja
autonomicznej kontynuacji nie została realnie zweryfikowana.

### Port parity

Fail / open.

Project Dummy `AGENTS.md` zawiera compact Alex-native contract, ale `CLAUDE.md`
wciąż jest w dużej części po angielsku i ma starszy runtime contract. To
potwierdza, że FR8 wymaga osobnego przeglądu powierzchni Claude Port.

## Nowe findings

### Finding A — Runtime localization coverage is incomplete

Alex-native v1 nie może opierać się wyłącznie na core workflow prompts,
templates i generated instruction text. User-facing command renderers, help
text, status text, command files i port-specific runtime wrappers muszą być
osobną checklistą testową.

### Finding B — Bug reports need a hard no-patch guard

Obecny kontrakt conversation/read-only nie wystarcza. Agent potrafi słownie
zdiagnozować root cause, ale potem sam przełącza się w implementation. Potrzebny
jest mocniejszy guardrail: bug report / finding / observation is capture or
diagnosis, never code mutation, unless the user explicitly asks to fix or the
workflow reaches an approved implementation gate.

### Finding C — Full checkpoint behavior is still untested

Macierz potwierdziła początek workflowów, ale nie potwierdziła pełnych
checkpointów `spec` i `plan`: linki do sekcji, opcja autonomicznej kontynuacji
i stop conditions. To wymaga scenariusza z kontrolowaną zgodą na przejście
dalej albo osobnego harnessu rozmowy wieloturowej.

### Finding D — Analyze can over-escalate verification effort

S05 próbował zrobić browser/Playwright screenshot dla małej statycznej
aplikacji, a potem natrafił na brak browser runtime. Dla prostych analiz Sage
powinien umieć wybrać lekką ścieżkę evidence-first bez dociągania ciężkiego QA,
chyba że użytkownik poprosi o browser QA albo visual audit.

## Rekomendowany follow-up patch

Nie robić pojedynczego fixu `sage status` jako całego rozwiązania. Następny
patch powinien mieć cztery elementy:

1. Runtime localization inventory: `sage status`, help text, command workflow
   text, generated Codex/Claude instructions, command files.
2. No-spontaneous-fix guard: mocniejsza instrukcja i test real-agent dla promptu
   typu "Zauważyłem błąd..." bez implementacji.
3. Port parity check: osobny test/regeneration check dla `AGENTS.md`,
   `CLAUDE.md` i `.claude/commands/*`.
4. Checkpoint harness: scenariusz, który dochodzi do `spec`/`plan` checkpointu
   i sprawdza linki oraz opcję autonomii.

## Artifact docs addendum

Po tym raporcie uruchomiono osobną macierz dokumentacyjną, bo pierwsza macierz
nie dotarła do pełnego zapisu `brief/spec/plan/manifest`.

Report: `.sage/work/20260508-alex-native-operating-model/dummy-project-artifact-docs-report.md`.

Wynik:
- `build` zapisał `manifest.md`, `spec.md`, `plan.md`.
- `architect` zapisał `brief.md`, `spec.md`.
- `fix` zapisał `manifest.md`, `plan.md`.
- Body dokumentów jest głównie po polsku, ale template headings, `handoff`
  labels i część frontmatter title nadal przeciekają po angielsku.
