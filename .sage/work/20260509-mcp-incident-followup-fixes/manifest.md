---
cycle_id: "20260509-mcp-incident-followup-fixes"
title: "Fix: follow-upy z MCP incidents po odfiltrowaniu historii"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
needs-triage: true
source: ".sage/.mcp-incidents.log review"
scope:
  - ".sage/work/20260509-mcp-incident-followup-fixes/*"
  - ".sage/.mcp-incidents.log"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
  - "runtime/platforms/codex/harness/**"
---

# Fix: follow-upy z MCP incidents po odfiltrowaniu historii

## State

**Current phase:** intake - lista realnych follow-upow po review
`.sage/.mcp-incidents.log`. Implementacja nie zostala rozpoczeta.

**Next step:** Wejsc w `/sage:fix`, potwierdzic ktore punkty laczymy z
istniejacymi intake cycles, a ktore robimy w tym cyklu.

## Context

Przejrzano `.sage/.mcp-incidents.log` i porownano czasy incydentow z historia
commitow. Nie chcemy naprawiac rzeczy, ktore sa juz naprawione.

Historyczne albo prawdopodobnie zamkniete:

- `artifact_order_violation` - nie widac nowych wystapien po pozniejszych
  commitach wzmacniajacych `pre-tool-validate.sh`;
- podstawowy przypadek `post_completion_mutation` - czesciowo zalatany przez
  model `closeout_epilogue`.

Ponizej zostaja rzeczy realnie do poprawy albo "pol na pol".

## Realnie do poprawy

### 1. `decisions.md` jest traktowany jak zly manifest

Sage mysli, ze `.sage/decisions.md` powinien miec YAML frontmatter, czyli blok
na poczatku pliku:

```md
---
status: ...
---
```

Ale `decisions.md` to zwykly dziennik decyzji. On zaczyna sie od `# Decisions`
i to jest poprawne.

**Problem:** hook zglasza `broken_frontmatter`, mimo ze plik nie jest zepsuty.

**Fix direction:** nauczyc hook, ze `.sage/decisions.md` jest specjalnym typem
pliku i nie wolno go sprawdzac tak samo jak `manifest.md`, `plan.md` albo
`spec.md`.

### 2. Hook karze za stary brudny stan repo

W repo moze juz byc zmieniony `.sage/decisions.md`, np. przez poprzednia sesje.
Potem kolejna sesja robi cos innego, a hook patrzy na caly dirty worktree i
mowi: "ten plik jest zmieniony, ale ta sesja go nie zadeklarowala".

Technicznie to wychodzi jako `bypass_mutation` albo `unclaimed_change`.

**Problem:** to nie musi byc prawdziwy bypass. To moze byc legalna, starsza
zmiana, ktora po prostu nie jest jeszcze zacommitowana.

**Fix direction:** hook powinien rozroznic:

- co bylo brudne juz na starcie sesji;
- co zmienila obecna sesja;
- co jest rzeczywistym obejściem `apply_patch` albo workflow.

### 3. Intake manifest czasem wyglada jak "claim bez zmiany"

`claim_no_op` znaczy: agent powiedzial "zmieniam ten plik", ale po patchu hook
nie widzi realnej zmiany w `git status`.

Dla zwyklego kodu to moze byc prawdziwy warning. Ale przy intake manifestach
moze byc falszywy alarm, bo capture-only zmiany w `.sage/work/**` maja inny
sens niz implementacja kodu.

**Problem:** Sage moze straszyc warningiem przy legalnym zapisaniu nowego
intake/capture.

**Fix direction:** sprawdzic przypadki:

- nowy `.sage/work/<cycle>/manifest.md`;
- dopisanie do istniejacego intake manifestu;
- capture-only patch, ktory nie dotyka kodu.

Hook nie powinien zglaszac `claim_no_op`, jesli patch realnie zapisal legalny
capture/intake.

## Pol na pol

### 4. `phase_jump_observed` jest bardziej szumem niz bugiem

Ten wpis oznacza: "widze, ze manifest/spec/plan ma status `completed`".

Samo to nie jest blad. Problem jest taki, ze hook potrafi logowac to wiele razy,
jakby kazde ponowne zobaczenie `completed` bylo nowym wydarzeniem.

**Problem:** log robi sie glosny i trudniej zauwazyc prawdziwe problemy.

**Fix direction:** zrobic z tego jedno z dwoch:

- deduplikowany incident: loguj tylko pierwszy raz dla danego pliku/statusu;
- metryka harnessu, a nie zwykly incident w `.sage/.mcp-incidents.log`.

### 5. Documentation/capture-only zmiany potrzebuja lzejszego trybu

Czesc closeout problemu zostala juz ruszona przez `closeout_epilogue`, ale
szerszy problem nadal istnieje.

Sage czasem traktuje poprawki w `.sage/**` tak, jakby byly zmianami kodu
produkcyjnego. Na przyklad poprawka raportu QA albo dopisanie decyzji moze
uruchomic za twarde guardrails.

**Problem:** agent musi czasem tworzyc sztuczny cykl tylko po to, zeby zapisac
porzadkowa dokumentacje.

**Fix direction:** dodac osobny, audytowany tryb dla zmian typu:

- tylko `.sage/work/**`;
- tylko `.sage/docs/**`;
- `.sage/decisions.md`;
- bez kodu, testow i runtime behavior.

Taki tryb powinien byc lzejszy niz normalny implementation fix, ale nadal
zostawiac slad w logu.

## Related existing cycles

Ten manifest moze zostac rozbity albo polaczony z istniejacymi intake cycles:

- `.sage/work/20260509-closeout-documentation-mutation-model/`
- `.sage/work/20260509-decisions-capture-without-active-plan-fix/`
- `.sage/work/20260509-file-change-enforcement-fix/`
- `.sage/work/20260509-multi-active-cycle-model-fix/`

## Acceptance criteria

- `.sage/decisions.md` nie generuje falszywego `broken_frontmatter`.
- Stary dirty worktree nie jest automatycznie traktowany jak bypass obecnej
  sesji.
- Legalne capture/intake manifesty nie generuja falszywego `claim_no_op`.
- `phase_jump_observed` przestaje zasypywac incident log powtorzeniami.
- Capture/documentation-only `.sage/**` ma jasny, lzejszy i audytowany tryb.
