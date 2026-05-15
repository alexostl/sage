---
title: "ADR - Doc lifecycle, decisions i bookkeeping"
status: accepted
date: 2026-05-14
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
accepted_at: "2026-05-14"
accepted_by: "alexostl"
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/brief.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
---

# ADR - Doc lifecycle, decisions i bookkeeping

## Context

Sage SelfHost zaczal puchnac nie dlatego, ze ma duzo plikow, tylko dlatego, ze
kilka rodzajow wiedzy zaczelo mieszkac w tych samych miejscach:

- aktywny workflow state;
- audit trail decyzji;
- process log checkpointow i auto-review;
- bogate manifesty opisujace sedno problemu;
- raw evidence z harnessow;
- historyczne long-form docs.

Najbardziej widoczny symptom to `.sage/decisions.md`: ok. 390 decyzji i ponad
8k linii w kilka dni. Subagent analysis pokazala, ze workflow logowal prawie
kazdy krok procesu jako osobna decision: root-cause checkpoint, auto-review,
revision, approval, plan review, completion checkpoint i closeout.

## Decision

### 1. Manifest pozostaje source-of-truth dla state

`manifest.md` jest kanonicznym zrodlem prawdy dla lifecycle state:
`status`, `phase`, `scope`, `resolution`, `folded_into`, `closed_at` i
powiazane pola.

Body manifestu pozostaje bogate, bo jest najlepszym ludzkim opisem problemu.
Nie wprowadzamy domyslnych `summary.md`. Zamiast redukowac manifesty, wymagamy
spojnosci sekcji `## State` z frontmatter.

### 2. Live work-index formalizuje manifestowa czesc `sage status`

Nie tworzymy nowego recznie edytowanego indeksu. "Work-index" oznacza lekki
live view generowany z manifestow. `sage status --json` moze pozostac composite
output, ale musi rozdzielac:

- `work_index` / `cycles` - lifecycle state z manifestow;
- `recent_decisions` - kontekst decyzji, nie state source;
- `health` - operational health, nie czesc work-index.

Na start nie dodajemy persistent cache. Jezeli live scan kiedys stanie sie za
wolny, cache moze trafic do `.sage/.cache/...`, zgodnie z istniejaca konwencja.

### 3. `decisions.md` jest decision logiem, nie process logiem

Do `.sage/decisions.md` trafiaja tylko zdarzenia, ktore realnie zmieniaja
przyszle decyzje agenta lub Alexa:

- finalnie zaakceptowany root cause;
- finalnie zaakceptowany plan/scope gate;
- scope expansion;
- final closeout;
- trwala zasada projektowa;
- decyzja uzytkownika zmieniajaca kierunek, priorytet, ownership albo ryzyko.

Nie trafiaja tam domyslnie:

- auto-review verdict jako osobny globalny wpis;
- `needs revision` po review;
- intermediate root-cause checkpoint przed akceptacja;
- kazda rewizja planu/root-cause;
- completion checkpoint przed final approval;
- pure bookkeeping reconciliation;
- szczegolowy verification output, jesli jest w planie, manifest body albo
  QA/report artifact.

Milestone implementacyjny musi zastapic stare compliance surfaces, ktore dzisiaj
wymuszaja mikrodecyzje: Rule 7 wording, workflow checkpoint wording,
auto-review/auto-QA wording oraz harness Signal 8/testy laczace frontmatter
flips z obowiazkowym `.sage/decisions.md` update.

### 4. Decisions retention: 50 current + one newest-first archive

`.sage/decisions.md` trzyma 50 najnowszych decyzji.

Starsze decyzje trafiaja do jednego `.sage/decisions-archive.md`, preferencyjnie
newest-first, tak zeby current i archive mialy spojna logike czytania.

Archive read jest search-first: agent uzywa `rg`, potem czyta maly fragment.
Full archive read jest dozwolony tylko z nazwanym powodem, np. gdy `rg` nic nie
znajduje, trafienia nie daja potrzebnego kontekstu, potrzebny jest pelny audyt,
archive moze byc uszkodzony, user jawnie prosi o pelny audyt albo agent wykonuje
migracje/naprawe archive.

W linked Git worktree rotacja nie rusza archive. Overflow ponad 50 decyzji w
worktree jest legalny i tymczasowy. Rotacja archive wykonuje sie automatycznie
tylko poza linked worktree. Detection ma byc mechaniczne i tanie, oparte o Git
metadata, np. relacje `git rev-parse --git-dir` i
`git rev-parse --git-common-dir`. Archive rotation ma jeden legalny writer path:
primary checkout, nie rownolegle linked worktrees.

### 5. Completed-cycle bookkeeping reconciliation

Completed cycles pozostaja audytowalne, ale czysty bookkeeping moze byc
naprawiany bez follow-up cycle i bez decisions entry.

Dozwolone przyklady:

- stale `Next step`;
- body niespojne z frontmatter;
- `phase: verify` przy `status: completed`;
- brakujace `closed_at`;
- brakujace `resolution` / `folded_into`;
- oczywiste pointer/source bookkeeping.

Nie jest bookkeepingiem zmiana faktow historycznych: scope, approval meaning,
verification evidence, implementation result albo ocena, czy fix byl poprawny.

Bookkeeping reconciliation nie tworzy nowego summary, global decision entry ani
osobnego audit logu, jesli patch jest jednoznacznie pure bookkeeping. Jesli
zmiana dotyka faktow historycznych albo jej charakter nie jest oczywisty, nie
korzysta z tego wyjatku i musi przejsc normalny workflow.

### 6. Reopen jest wyjatkiem same-conversation

`reopen` jest legalny tylko jako natychmiastowa korekta w tej samej aktywnej
rozmowie, zanim agent przejdzie do innej pracy albo zakonczy handoff.

Jesli blad zamknietego fixa zostaje odkryty pozniej, domyslnym modelem jest
follow-up cycle. Jesli to tylko bookkeeping, stosujemy bookkeeping
reconciliation bez follow-up.

### 7. Closeout path waliduje spojnosc

Primary consistency mechanism to closeout path, nie `sage doctor` i nie
`sage status` warnings.

Minimalna walidacja closeout:

- `status: completed` idzie z `phase: completed`;
- `## State` albo rownowazne state fields nie zawieraja aktywnego next step;
- folded/sibling intake ma `resolution` / `folded_into`;

Phrase scan po prozie jest tylko advisory. Frazy typu `completion-checkpoint`,
`verify`, `commit/push pending` nie moga byc samodzielnym blocking source bez
strukturalnego potwierdzenia niespojnosci.

Na start nie wymagamy hooka. Hook moze zostac dodany pozniej tylko, jesli
workflow-level validation nie wystarczy i da sie to zrobic malym mechanizmem.

## Consequences

### Positive

- Codzienny status moze pozostac lekki.
- Agenci nie musza czytac raw historii, zeby zrozumiec aktywny state.
- `decisions.md` przestaje byc process logiem.
- Worktree merge conflicts wokol decisions archive powinny byc mniejsze, bo
  linked worktrees nie ruszaja archive.
- Bogate manifesty zostaja, ale musza byc spojne.

### Trade-offs

- Czesc informacji z auto-review i checkpointow nie bedzie globalnie widoczna w
  `decisions.md`; musi byc wlasciwie zapisana w manifestach/planach/reportach.
- Jeden archive moze z czasem urosnac, ale regula search-first ogranicza token
  load. Pelny odczyt archive jest wyjatkiem, nie standardem.
- Brak hooka na start oznacza, ze closeout discipline musi byc poprawnie
  wdrozona w workflow/tooling.
- Finalna implementacja ma uruchomic pelny RealHarness. To daje wieksza pewnosc
  real-agent behavior, ale jest drozsze niz targeted run; targeted scenarios
  zostaja przyszlym usprawnieniem.

## Status

Accepted. Alex wybral `[S] Skip review` po rewizji designu wedlug subagent
review.
