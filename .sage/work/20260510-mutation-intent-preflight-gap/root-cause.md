---
cycle_id: "20260510-mutation-intent-preflight-gap"
title: "Root cause: Batch 2 hook recovery i mutation preflight"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
---

# Root cause: Batch 2 hook recovery i mutation preflight

## Zakres diagnozy

Batch 2 laczy szesc intake'ow:

- `20260510-mutation-intent-preflight-gap`
- `20260509-file-change-enforcement-fix`
- `20260509-binary-asset-mutation-contract-fix`
- `20260512-hook-recovery-scope-amputation-fix`
- `20260509-hook-block-recovery-behavior-fix`
- `20260509-blocking-hook-guidance-review`

Wspolny problem nie brzmi "zakazac git merge" ani "doprecyzowac jeden
komunikat hooka". To jest luka w kontrakcie przedmutacyjnym: agent nie ma jednej
obowiazkowej kontroli zamiaru zapisu przed pierwsza mutacja, a po bloku hooka
nie ma wystarczajaco twardej reguly, ze trzeba odzyskac pelny cel pracy zamiast
konczyc niepelny fix albo obchodzic threshold.

## Root cause

Sage ma obecnie trzy rozdzielone warstwy ochrony, ale nie ma jednego
agent-facing preflight contract, ktory agent musi wykonac zanim uzyje dowolnej
powierzchni mutujacej:

1. **PreToolUse** blokuje czesc mutacji zanim zapis sie wydarzy, ale tylko dla
   tool surfaces, ktore Codex wystawia jako `apply_patch|Edit|Write`,
   defensywnie `file_change`, albo `Bash`.
2. **Stop/turn audit** wykrywa niektore bypassy po fakcie przez porownanie
   `.sage/.session-mutations.log` z `git status`.
3. **Harness** ocenia rezultat real-agent runu, ale tylko tam, gdzie scenariusz
   ma rubryke stanu i transcript assertion.

Brakuje warstwy "zanim cokolwiek zapiszesz, sprawdz i nazwij": aktywny cykl,
zatwierdzony scope, liczba plikow, threshold workflow, stan closeout,
typ mutacji tekstowej/binarnej oraz recovery path po ewentualnym bloku.

## Evidence

### 1. Hook registry i README potwierdzaja ograniczony pre-hook surface

`runtime/platforms/codex/README.md` mowi, ze registry matchuje
`apply_patch|Edit|Write` oraz Stop, a PreToolUse obejmuje `file_change` tylko
"when the runtime surfaces them".

Dowody:

- `runtime/platforms/codex/README.md:55`
- `runtime/platforms/codex/README.md:62`
- `runtime/platforms/codex/setup/lib/hooks-deploy.sh:34`
- `runtime/platforms/codex/setup/lib/hooks-deploy.sh:41`

To oznacza, ze sam runtime hook nie jest pelna gwarancja przed pierwszym
zapisem. Gdy tool surface nie wystawi mutacji przed write-time, zostaje tylko
warstwa ex post.

### 2. PreToolUse ma walidacje path/scope, ale nie zastapi jawnej decyzji agenta

`pre-tool-validate.sh` potrafi:

- rozpoznac mutujacy Bash dla czesci komend i guarded paths;
- sparsowac `apply_patch` DSL oraz defensywnie `changes[]`;
- rozstrzygnac aktywny, parked albo bootstrap cycle;
- zablokowac out-of-scope paths, same-turn self-created implementation oraz
  Moderate+ code-first violation.

Dowody:

- `runtime/platforms/codex/hooks/pre-tool-validate.sh:39`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:55`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:152`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:247`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh:279`

Ale to nadal jest hook jako hard stop. Agent moze dojsc do prawidlowego stanu
metoda odbijania sie od blokad, zamiast wykonac preflight przed tool use. To
wprost widac w intake `20260510-mutation-intent-preflight-gap`: oczekiwany
problem to block-and-recover pattern, nie sama obecność blokady.

### 3. Stop/turn audit jest backstopem po fakcie, nie preflightem

`turn-audit.sh` porownuje claimed paths z realnym `git status` i emituje
`bypass_mutation`. To jest potrzebne, bo lapie untracked writes i bypassy, ale
dziala dopiero na Stop.

Dowody:

- `runtime/platforms/codex/hooks/turn-audit.sh:73`
- `runtime/platforms/codex/hooks/turn-audit.sh:108`
- `runtime/platforms/codex/hooks/turn-audit.sh:119`

To nie ochroni pracy przed konfliktem, dirty worktree ani niepelna odpowiedzia
agenta. Moze tylko wykryc, ze stalo sie cos niezatwierdzonego.

### 4. Historyczne QA pokazalo real-agent `file_change` bez hook trace

QA dla mutation enforcement pokazalo, ze realny Codex utworzyl
`src/notes/random.md` przez native `file_change`, bez incydentow i bez logow
hookow.

Dowody:

- `.sage/work/20260509-mutation-enforcement-target-safety-fix/qa-report.md:102`
- `.sage/work/20260509-mutation-enforcement-target-safety-fix/qa-report.md:115`
- `.sage/work/20260509-mutation-enforcement-target-safety-fix/qa-report.md:133`

Poprzedni systemic fix poprawil czesc harness rubrics i hook coverage, ale nie
usuwa klasy problemu: real-agent tool surface moze byc niewidoczny dla
pre-hooka albo widoczny za pozno.

### 5. Aktualny harness juz blokuje stare puste rubryki, ale nie pokrywa calego Batcha 2

Aktualny `v11-scenarios.json` ma rubryke dla scenariusza 03: zakazuje zmian w
`src/`, zakazuje `unclaimed_change`/`bypass_mutation` i wymaga transcriptowego
sygnalu blokady/recovery.

Dowody:

- `runtime/platforms/codex/harness/v11-scenarios.json:46`
- `runtime/platforms/codex/harness/v11-scenarios.json:51`
- `runtime/platforms/codex/harness/lib/aggregate-signals.sh:217`

To zabezpiecza stary P1 przed regresja, ale nie dowodzi jeszcze poprawnego
zachowania dla: mutujacego Bash/git powodujacego konflikty, legalnych binary
asset mutations poza `apply_patch`, recovery po trzecim wymaganym pliku oraz
komunikatow blokujacych, ktore maja prowadzic agenta dalej.

### 6. Konstytucja ma zasade "nie redukuj scope", ale hook recovery nie wymusza jej w scenariuszu blokady

Konstytucja mowi, ze source/runtime/test/instruction behavior wymaga workflow i
approved scope bez wzgledu na tool, oraz ze agent nie moze jednostronnie
redukcowac scope.

Dowody:

- `core/constitution/sage-process.constitution.md:54`
- `core/constitution/sage-process.constitution.md:152`

Failure mode z intake'ow Batcha 2 jest dokladnie na tej granicy: hook mowi
"zatrzymaj sie albo podnies workflow", a agent interpretuje to jako "usun
trzeci plik z celu" albo "zakoncz po bloku".

## Chain

1. Uzytkownik prosi o prace, ktora implikuje mutacje.
2. Agent nie ma formalnego kroku "mutation preflight" przed tool use.
3. Jesli uzyje widocznego `apply_patch`/`Edit`/`Write`, hook moze zablokowac
   zapis i podac recovery.
4. Jesli uzyje niewystarczajaco widocznego `file_change`, mutujacego Bash/git
   albo binarnej operacji poza `apply_patch`, zapis moze wydarzyc sie przed
   pelna walidacja albo dopiero Stop go wykryje.
5. Po bloku agent moze wybrac niepelna sciezke: zakonczyc, zmniejszyc zakres,
   stworzyc self-approved manifest albo kontynuowac bez escalation.
6. Harness ma regression checks dla czesci starych przypadkow, ale nie dla
   calego kontraktu Batcha 2.

## Konkluzja

Root cause Batcha 2 to brak jednego, testowalnego kontraktu:

> Przed pierwsza mutacja agent musi jawnie sprawdzic i nazwac intent: tool
> surface, typ mutacji, aktywny cykl, zatwierdzony scope, threshold, closeout
> state i recovery/escalation path. Hooki sa hard stopem i audytem, ale normalna
> sciezka pracy ma prowadzic agenta zanim hard stop bedzie potrzebny.

## Confidence

**High** dla ogolnej diagnozy: evidence z hookow, harnessu, konstytucji i
historycznego QA wskazuje na ten sam brak kontraktu.

**Medium** dla dokladnego planu implementacji: trzeba jeszcze rozdzielic, co
powinno byc w generated `AGENTS.md`/workflow guidance, co w `pre-tool-validate`,
co w `turn-audit`, a co w real-agent harness scenarios.

## Scope preview

To bedzie **Systemic fix**, bo prawdopodobnie dotknie kilku warstw:

- generated Codex contract / AGENTS guidance;
- hook messages i Bash/file mutation handling;
- harness scenarios dla mutation preflight oraz scope-amputation recovery;
- testy hookow i aggregate/harness;
- sibling intake bookkeeping po zweryfikowanym fixie.

Bez zatwierdzonego planu nie wolno implementowac zadnych z tych zmian.

## Root cause gate

Nastepny legalny krok to decyzja Alexa:

- `[A] Subagent review` - read-only review diagnozy, potem ewentualne planowanie;
- `[S] Skip review` - akceptujesz diagnoze bez niezaleznego review;
- `[R] Revise` - poprawiamy albo doprecyzowujemy root cause;
- `[K] Stuck` - zmieniamy sposob diagnozy;
- `[N] New session` - parkujemy tutaj.
