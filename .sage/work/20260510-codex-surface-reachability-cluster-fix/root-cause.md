---
cycle_id: "20260510-codex-surface-reachability-cluster-fix"
title: "Root cause: klaster powierzchni Codex i reachability skilli"
workflow: fix
phase: root-cause-gate
status: completed
created: 2026-05-10
updated: 2026-05-10
---

# Root Cause: klaster powierzchni Codex i reachability skilli

## Problem

Codex ma kilka sąsiadujących miejsc, w których może zgubić, zdublować albo
osłabić instrukcje Sage zanim workflow w ogóle się zacznie:

1. **Selfhost loader paths używają ścieżek target repo.**
   `.agents/skills/sage:*` w repo frameworka wskazują na
   `sage/core/workflows/**`, ale workflowy selfhost są pod
   `core/workflows/**`.
2. **Config funkcji hooks ma drift.**
   Aktywna powierzchnia Codex Desktop ostrzega, że
   `[features].codex_hooks` jest przestarzałe na rzecz `[features].hooks`, a
   generator Sage i helpery configu nadal zawierają stare wykonywalne
   założenia.
3. **`sage-navigator` może dryfować od źródła prawdy.**
   Widoczny dla Codexa `.agents/skills/sage-navigator/SKILL.md` jest
   wdrożoną kopią i może zostać za
   `core/capabilities/orchestration/sage-navigator/SKILL.md`.
4. **Publiczny Sage entrypoint jest zdublowany.**
   Codex wystawia jednocześnie `.agents/skills/sage/SKILL.md` i wygenerowany
   `.agents/skills/sage:sage/SKILL.md`, przez co ogólne wejście Sage jest
   niejasne w UI i routingu.

## Przyczyna

Powierzchnia Codex Stage 7/config nie ma jednego jawnego modelu public surface.
Miesza trzy różne pojęcia:

- workflow loader stubs generowane z `core/workflows/*.workflow.md`;
- ręcznie utrzymywane albo kopiowane router skills wyższego poziomu, takie jak
  `sage` i `sage-navigator`;
- klucze aktywacji/configu platformy Codex, które decydują, czy hooks i loader
  guidance faktycznie działają.

Ponieważ te rzeczy są generowane i testowane jako osobne małe przypadki, Sage
może jednocześnie przechodzić test loaderów target repo, mieć zepsute selfhost
loader stubs, zachowywać starą kopię navigatora, trzymać zdublowany
`sage:sage` entrypoint i aktualizować runtime hooks bez pełnego spięcia
wygenerowanych helperów configu.

## Dowody

- Cluster map mówi, że cztery source intakes należą razem, bo wszystkie dotyczą
  instruction reachability i adaptera Codex.
- `skills-deploy.sh` ma hard-code
  `sage/core/workflows/${wf}.workflow.md` dla każdego workflow loadera.
- `stage7-skills.bats` sprawdza target path behavior i dziś broni loadera
  `sage:sage`, więc testy utrwalają część zdublowanej powierzchni.
- Lokalny scan selfhost pokazał, że 16/16 `.agents/skills/sage:*` loader stubs
  wskazuje na brakujące ścieżki `sage/core/workflows/*.workflow.md`.
- Intake hooks flag ma realny dowód z ostrzeżenia Codex Desktop, a wygenerowany
  config Sage i kod helperów nadal odnoszą się do `codex_hooks`.
- Intake navigator drift zapisuje, że wystawiony Codex skill może zostać za
  źródłem core capability.

## Docelowy kształt fixa

To powinien być jeden Systemic `/sage:fix` dla całego klastra:

- jawnie zdefiniować Codex public skill surface;
- zrobić Stage 7 path-aware dla target repo vs selfhost repo;
- zdecydować i egzekwować, czy `sage-navigator` jest kopiowany, czy wystawiany
  jako loader stub;
- usunąć albo obsłużyć specjalnie redundantny `sage:sage`, jeśli decyzja o
  public surface potwierdzi, że nie jest wspierany;
- spiąć wygenerowany hooks feature config i wykonywalne config helpers z aktualnym
  kontraktem Codex Desktop;
- dodać testy regresji, które pokrywają public surface jako całość, nie tylko
  jedną wygenerowaną fixture target repo.

## Granice

- Nie mutować `alex-os-dev` w tym cyklu. To zostaje cross-repo follow-upem,
  który wymaga osobnej zgody.
- Nie przepisywać wszystkich historycznych dokumentów wspominających
  `codex_hooks`; w tym patchu mieszczą się tylko wykonywalne powierzchnie
  generator/config/test, chyba że plan review doda konkretny target
  dokumentacyjny.
- Nie traktować naprawy loader path jako kompletnego wyniku. To jest pierwszy
  wycinek diagnostyczny wewnątrz klastra, nie wynik klastra.

## Rekomendowany następny krok

Zatwierdzić albo zrewidować tę diagnozę, potem przygotować jeden plan dla całego
patcha klastra C.
