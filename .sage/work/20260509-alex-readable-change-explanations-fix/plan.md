---
cycle_id: "20260509-alex-readable-change-explanations-fix"
title: "Fix plan: Batch 7 Alex-native communication and report language"
workflow: fix
phase: fix-scope-gate
status: in-progress
created: 2026-05-14
updated: 2026-05-14
classification: Moderate
---

# Fix plan: Batch 7 Alex-native communication and report language

## Scope classification

**Classification:** Moderate.

Ten fix dotyka kilku prompt/runtime surfaces i testów tekstowych, ale nie
zmienia API, hook behavior, formatu frontmatter ani architektury Sage. To jest
naprawa kontraktu komunikacyjnego: agent ma tłumaczyć błędy/findings
czytelniej dla Alexa bez upraszczania ich do poziomu "dla dziecka", a
raportowe workflowy mają jasno traktować angielskie template'y jako strukturę,
nie język docelowy.

## Target communication style

Docelowy styl to middle ground między wewnętrznym raportem systemowym a zbyt
prostym objaśnianiem. Agent nie ma ukrywać terminów technicznych, ale ma je
osadzić w skutku i przyczynie, żeby Alex wiedział, dlaczego mechanizm ma
znaczenie.

Wzorzec:

1. **Co się dzieje:** jedno konkretne zdanie o widocznym zachowaniu albo
   decyzji.
2. **Czemu to problem:** krótki impact dla pracy Alexa, workflowu albo ryzyka
   utrzymania.
3. **Jak to się technicznie nazywa:** canonical term w backtickach, jeśli
   pomaga precyzji.
4. **Co trzeba zmienić:** następny praktyczny krok albo granica scope.

Kalibracja poziomu:

- Nie mówić jak do początkującego użytkownika bez kontekstu. Alex jest Junior
  Dev Vibecoder: rozumie repo, pliki, testy i workflow, ale nie zawsze ma w
  głowie wewnętrzne nazwy Sage.
- Nie tłumaczyć oczywistych terminów programistycznych (`test`, `hook`,
  `manifest`, `frontmatter`, `workflow`) za każdym razem.
- Nie zaczynać od samych etykiet typu `broken_frontmatter`,
  `bypass_mutation`, `phase_jump_observed`, jeśli można najpierw powiedzieć,
  jaki skutek widzi człowiek.
- Dodać około 20-30% kontekstu tam, gdzie bez niego finding brzmi jak
  wewnętrzny log, ale zatrzymać się przed eseistycznym tłumaczeniem.

Przykład docelowy:

```text
Sage traktuje poprawny `decisions.md` jak uszkodzony plik, bo oczekuje
frontmatter tam, gdzie ten dziennik go nie ma. To blokuje legalne dopisanie
decyzji i wygląda jak awaria workflowu, chociaż problemem jest zbyt szeroka
walidacja. Technicznie to `broken_frontmatter` false positive dla specjalnego
artefaktu. Fix powinien nauczyć guard, że `decisions.md` jest wyjątkiem, bez
rozluźniania walidacji dla zwykłych manifestów.
```

Przykład zbyt uproszczony:

```text
Sage się myli i trzeba mu powiedzieć, że ten plik jest specjalny.
```

Przykład zbyt techniczny:

```text
`broken_frontmatter` na `.sage/decisions.md` wymaga whitelisty dla
non-frontmatter artifacts.
```

## Files to change

Subagent review planu wymusił zawężenie scope: implementacja może dotknąć tylko
plików niżej oraz generated `AGENTS.md`, jeżeli `bin/sage update` pokaże realny
diff wynikający ze zmian w `agents-md.sh` / source workflowach. Szerokie globy
typu `core/workflows/**` i `runtime/platforms/codex/setup/tests/**` nie są
częścią zatwierdzanego planu.

- `core/constitution/sage-process.constitution.md`
  - Rozszerzyć istniejący bullet Alex-native o jedno krótkie zdanie lub
    podpunkt: przy bugs/findings/fix plans/trade-offs agent najpierw opisuje
    visible behavior albo decision impact, potem cause/risk, potem technical
    mechanism i next action.
  - Użyć języka "plain technical prose", nie "explain like I'm five".
  - Nie dodawać długich przykładów do constitution; to jest always-loaded
    source i ma zostać zwarte.

- `runtime/platforms/codex/setup/lib/agents-md.sh`
  - Zmirrorrować kompaktowy kontrakt do generated `AGENTS.md`.
  - Dodać pełny wzorzec odpowiedzi: `co się dzieje -> czemu to problem -> jak
    to się technicznie nazywa -> co trzeba zmienić`.
  - Dodać frazę, że techniczne nazwy są nadal używane, ale nie jako pierwszy i
    jedyny sposób wyjaśnienia.
  - Zachować compact generated text: maksymalnie kilka linii w istniejącej
    sekcji `Alex-native operating contract`.

- `core/workflows/qa.workflow.md`
  - Przy Step 5 dopisać, że `qa-report-template.md` daje strukturę raportu, a
    natural-language prose ma iść za project language contract.
  - W Alex-native selfhost oznacza to polską prozę przy zachowaniu raw outputów,
    ścieżek, command names i identyfikatorów.
  - Doprecyzować, że bug descriptions w raporcie mają używać tego samego
    middle-ground patternu: expected/actual/evidence zostają konkretne, ale
    opis findings zaczyna się od skutku i przyczyny, nie od samej etykiety.

- `core/workflows/design-review.workflow.md`
  - Dodać analogiczny kontrakt przy `design-review-template.md`.
  - Wyraźnie nie zmieniać klasyfikacji mechanical/manual findings.
  - Dopisać, że "What's wrong" i "What right looks like" mają być pisane w
    project language prose, z zachowaniem token names, component names, file
    paths i raw browser evidence.

- `develop/templates/qa-report-template.md`
  - Dodać krótki komentarz guidance jak w innych template'ach:
    Alex-native self-host używa polskiej prozy i zachowuje canonical terms.
  - Nie tłumaczyć całego template'u.
  - Komentarz ma jasno powiedzieć: template headings/field names są szkieletem;
    wypełniana treść natural-language ma podążać za project language contract.

- `develop/templates/design-review-template.md`
  - Dodać taki sam krótki komentarz guidance.
  - Nie zmieniać struktury sekcji poza komentarzem.
  - W komentarzu uwzględnić design-specific evidence: design tokens, component
    names, CSS values i browser evidence zostają canonical/verbatim.

- `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - Dodać regresje tekstowe dla:
    - konkretnego wzorca wyjaśniania w constitution;
    - QA/design-review workflow language override przy report template'ach;
    - Alex-native guidance w `qa-report-template.md` i
      `design-review-template.md`.
  - Testy mają łapać semantyczne anchor phrases, nie pełne akapity, żeby drobna
    redakcja nie łamała testów bez potrzeby.

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - Dodać regresję, że generated `AGENTS.md` zawiera pełny wzorzec:
    `co się dzieje`, `czemu to problem`, `jak to się technicznie nazywa`,
    `co trzeba zmienić`.
  - Dodać assertion, że generated text nadal mówi o `technical mechanism`, żeby
    utrzymać middle ground zamiast wypchnąć techniczne nazwy z odpowiedzi.

- `AGENTS.md`
  - Regenerowany output po `bin/sage update`, jeśli zmiana generatora wymaga
    aktualizacji tracked generated instructions.
  - Jeżeli `bin/sage update` zmieni dodatkowe generated surfaces, wolno je
    zaakceptować tylko po sprawdzeniu diffu i tylko gdy wynikają bezpośrednio z
    zatwierdzonych source changes. Inaczej zatrzymać się na scope expansion.

- `.sage/work/20260509-qa-workflow-polish-report-contract/manifest.md`
  - Przy closeout oznaczyć jako folded/source intake Batcha 7, jeżeli
    implementacja faktycznie zamknie jego acceptance criteria.

- `.sage/decisions.md`
  - Dopisać decyzję closeoutową po weryfikacji.

## Tests to add or modify first

1. Zmienić `alex-native-core-text.bats`, żeby najpierw oblał brak:
   - middle-ground explanation order w constitution;
   - QA/design-review report template language override;
   - guidance w dwóch raportowych template'ach.
2. Zmienić `stage3-agents-md.bats`, żeby najpierw oblał brak pełnego wzorca w
   generated `AGENTS.md`.

Expected initial failure: nowe `grep` assertions nie znajdą docelowych fraz.

Proponowane anchor phrases dla testów:

- constitution:
  - `plain technical prose`
  - `visible impact and cause`
  - `technical mechanism`
  - `next action`
- generated `AGENTS.md`:
  - `co się dzieje`
  - `czemu to problem`
  - `jak to się technicznie nazywa`
  - `co trzeba zmienić`
  - `technical mechanism`
- QA/design-review workflow:
  - `template provides structure`
  - `project language contract`
  - `raw evidence`
  - Te assertions mają być kontekstowe: powinny sprawdzać wording przy Step 5,
    obok `Use the report template...` / `Use template from...`, a nie tylko
    ogólny `Artifact Language Contract` na początku workflowu.
- report templates:
  - `Alex-native self-host`
  - `project language contract`
  - `Preserve`

## Implementation order

1. Dodać failing text assertions w dwóch Bats testach.
   - Najpierw uruchomić focused tests i zachować failure output jako dowód TDD.
2. Wzmocnić minimalnie `core/constitution/sage-process.constitution.md`.
   - Zmienić tylko Alex-native section.
   - Nie dodawać nowych sekcji globalnych ani przykładów.
3. Wzmocnić compact generated contract w `agents-md.sh`.
   - Zmiana ma mirrorować constitution, ale być krótsza.
   - Po zmianie wygenerowany `AGENTS.md` ma mieć nowy pattern bez rozpychania
     reszty Operating Kernel.
4. Dodać language override do `qa.workflow.md`.
   - Najlepsze miejsce: bezpośrednio po `Use the report template...`.
   - Wording ma wyjaśniać, że template jest szkieletem i raport prose idzie za
     project language contract.
5. Dodać language override do `design-review.workflow.md`.
   - Najlepsze miejsce: bezpośrednio po `Use template from...`.
   - Doprecyzować `What's wrong` / `What right looks like` bez zmiany
     klasyfikacji findings.
6. Dodać krótkie Alex-native guidance comments do dwóch report template'ów.
   - Forma jak w `manifest-template.md`: HTML comment przed code blockiem.
   - Nie tłumaczyć nagłówków template'u, żeby nie mieszać struktury.
7. Uruchomić focused tests i poprawić wording tylko jeśli testy pokażą realny
   drift.
8. Uruchomić `bin/sage update`, sprawdzić generated surfaces i tracked diff.
   - Jeśli update dotknie surface spoza `AGENTS.md`, najpierw sprawdzić, czy
     plik jest tracked i czy diff wynika z zatwierdzonych source changes.
   - Jeśli diff jest niezwiązany albo wymaga nowego generated surface w scope,
     zatrzymać się na scope expansion zamiast "wziąć przy okazji".
9. Uzupełnić Batch 7 bookkeeping i closeout artifacts dopiero po zielonej
   weryfikacji.

## Verification

Focused verification:

```text
bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
```

Generated/runtime verification:

```text
bash -n runtime/platforms/codex/setup/lib/agents-md.sh
bin/sage update
git diff --check
```

Jeżeli `bin/sage update` dotknie więcej generated surfaces niż oczekiwane
`AGENTS.md`, trzeba sprawdzić, czy są tracked i czy diff wynika z zatwierdzonego
source scope. Niezwiązany generated diff albo potrzebę dodania nowego generated
surface traktować jako scope expansion, nie automatyczną część fixa.

## Rollback

Rollback jest prosty: cofnąć zmiany w wymienionych source/test files oraz
ponownie uruchomić `bin/sage update`, żeby generated `AGENTS.md` wrócił do
poprzedniej treści. Zmiany są tekstowe i nie dotykają danych użytkownika,
hook runtime behavior ani publicznego API.

## Risk and minimization

Największe ryzyko to prompt bloat: zrobimy za dużo nowych zasad w wielu
miejscach i zwiększymy koszt czytania instrukcji. Minimalizacja: jeden krótki
wspólny pattern w constitution/generatorze, a w QA/design-review tylko lokalne
doprecyzowanie relacji template -> project language. Nie tłumaczymy całych
template'ów i nie ruszamy workflowów, które nie mają tego samego konkretnego
problemu.
