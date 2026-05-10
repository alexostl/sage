---
title: Postmortem — Codex enforcement activation cycle (M1+M2+M3)
date: 2026-04-29
status: dead-end
verdict: outcome-failed
related_commits:
  - 28b0782 (M0+M1+M2)
  - 03dfee3 (M3)
revert_commit: tbd
follow_up_cycle: 20260429-codex-l4-redesign (paused)
---

# Postmortem — Codex enforcement activation

## Verdict

**Ślepa uliczka.** Cykl został mechanicznie domknięty (78/78 testów PASS,
wszystkie milestone'y zrealizowane), ale na pierwszym realnym teście
empirycznym L4 enforcement zawiódł. Cofamy kod do stanu sprzed cyklu
i zostawiamy planning artifacts (brief.md, spec.md, plan.md,
verification.md) jako historyczny ślad próby.

## Co próbowaliśmy zrobić

Aktywować trzy warstwy enforcementu Sage na Codex:

- **L4 — Codex hooks (`UserPromptSubmit`)** — domyślnie ON po
  `sage update`/`sage init`, z mechanizmem klasyfikacji prompta przez
  regex słów-kluczowych (`build|implement|create|...` →
  wymaga spec.md+plan.md, `fix|debug|...` → wymaga root-cause checkpointu,
  `architect|...` → wymaga brief.md).
- **L5 — Pre-commit gate** — `core.hooksPath` + `.githooks/pre-commit`,
  blokujący commity bez aktywnej inicjatywy w `.sage/work/`. Dodano
  flagę `--force-githooks` dla projektów z istniejącym frameworkiem
  (husky, lefthook, pre-commit, simple-git-hooks).
- **Behavioral isolation skili (M3)** — per-skill `agents/openai.yaml`
  z `policy.allow_implicit_invocation: false` żeby Codex nie auto-suggestował
  direct skili na semantyczny match z opisu.

Plus pre-flight (M0): SHA256 versioning hooków, atomic JSON merge z backup'em,
fixture'y testowe.

## Co dało się zrealizować mechanicznie

- 78/78 testów jednostkowych PASS (M1: 22, M2: 24, M3: 32)
- Generator Codex deployuje wszystkie artefakty (yaml isolation, hooks,
  versions, githooks)
- `sage status` poprawnie raportuje stan Skills i L5 w 6/5 stanach każdy
- Bulk deploy demo: 34/34 direct skille z yaml, 17 workflow skili reactive
- Idempotencja generatora zachowana
- `name:` invariant zachowany (nie tknęliśmy slug'ów)

## Co poszło nie tak

Pierwszy realny test na świeżym projekcie (`/Users/alexostl/Developer/dummy-project`):

1. `sage init` zadziałał — wygenerował `.codex/`, `.agents/`, AGENTS.md,
   `agents/openai.yaml` per direct skill, `codex_hooks = true`.
2. Status: hooki ACTIVE, Skills ACTIVE.
3. User prompt do Codex: `"chce zbudowac prosty to do app, ktory bedzie
   dzialal jako apka webowa i ma miec minimalna liste zaleznosci"`.
4. **Codex zbudował todo app (index.html, styles.css, app.js, README.md)
   bez `/sage` routingu, bez `spec.md`/`plan.md`, bez checkpointów.**
5. Codex sam z siebie napisał na końcu: "skróciłem proces Sage, bo zadanie
   było małe i świeże".

Outcome: agent NIE podążył za frameworkiem mimo aktywnego L4. Dokładnie
ten failure mode który L4 miał blokować.

## Root cause

Klasyfikator regex w `runtime/platforms/codex/hooks/pre-prompt.sh` jest
**strukturalnie niezdolny do działania** dla realnych user prompt'ów:

```python
BUILD_RE = re.compile(
    r"\b(?:please\s+)?"
    r"(?:build|implement|create|develop|ship|deliver|introduce|add)"
    r"\b[^.?!\n]*?\b"
    rf"(?:{BUILD_NOUNS})\b",
    re.IGNORECASE,
)
```

Lista czasowników i rzeczowników jest **anglojęzyczna i zamknięta**.
Polski czasownik `zbudowac` nie matchuje `build|implement|create|...`,
więc hook poszedł w passthrough — emisja sticky context, ale bez
`decision: "block"`. Codex dostał normalny turn jakby gate'u nie było.

**Czemu testy tego nie złapały:** Wszystkie 78 testów weryfikowało
*mechanikę* (czy hook poprawnie blokuje gdy jest match, czy idempotentnie
deployuje pliki, czy yaml ma poprawny format). Żaden test nie weryfikował
*outcome* — że na realnym user prompt'cie po polsku z literówką gate by
faktycznie zablokował.

## Dlaczego to nie jest naprawiałne dorzuceniem słownika

Poza polskim, te same regex są ślepe na:

- **Literówki:** `buidl`, `creat`, `implemnt`, `feture` — żaden nie matchuje
- **Synonimy spoza listy:** `knock together`, `spin up`, `stand up an
  endpoint`, `wire up the form`, `yeet onto the page`
- **Pasywne sformułowania:** `the dashboard needs to exist by Friday`
- **Slang i skrótowce:** `pls implemnt login`, `lemme just throw together a UI`
- **Inne języki użytkownika:** każdy nowy język = pełny słownik do
  utrzymania, plus literówki w tym języku

Każdy taki bypass jest **cichy** — hook emituje passthrough, użytkownik
nie widzi sygnału, agent kontynuuje normalnie. Failure mode "gate się
nie aktywował" jest nieodróżnialny od "gate'u nie było wcale".

## Dlaczego mimo to commitowaliśmy 78/78 PASS

Kalibracja sukcesu była proxy-driven, nie outcome-driven:

- Cel testów: "regex blokuje gdy match" → spełnione
- Cel realny: "user'owi nie da się obejść routingu na produkcji" → niesprawdzone

To powtórzenie wzorca z [LRN:correction] *Line-count parity to proxy*:
testowaliśmy artifact behavior, nie behavior outcome. Pilot empiryczny był
zaplanowany w verification.md jako "deferred do user" — i to user wykonał
go pierwszym promptem, znajdując dziurę.

## Reguła do zapamiętania

**Mechanizm enforcementu oparty na klasyfikacji prompta przez regex
słów-kluczowych jest strukturalnie niezdolny do działania.** Nie ma
takiej listy słów, która pokryje wszystkie języki, wszystkie literówki,
wszystkie synonimy i wszystkie sposoby wyrażania intencji. Każda lista
to znana dziura + reaktywne utrzymanie + ciche failure mode.

Implikacja projektowa: L4 (lub każdy inny gate na poziomie prompta) musi
być oparty na mechanizmie, który NIE wymaga znajomości słownika
użytkownika. Kandydaci do rozważenia w następnym cyklu:

- **(A) Default-block strategy** — blokuj każdy pierwszy turn poza
  oczywistym `$skill` / read-only Q. Inwersja domyślnej decyzji.
  Język-agnostyczny, typo-immune. Cost: jeden reminder w turn 1.
- **(B) Self-classification by Codex** — hook wstrzykuje instrukcję
  "OCEŃ czy ten prompt to Standard+ i jeśli tak, NAPISZ `Sage → [workflow]`
  jako pierwszą linię". Bez dodatkowego LLM call (Codex sam jest LLM).
  Cost: model decyduje, więc miękki gate.
- **(C) Gate na PreToolUse zamiast UserPromptSubmit** — blokuj gdy agent
  próbuje `Edit`/`Write` na pliku w repo bez `.sage/work/<active>/spec.md`.
  Outcome-driven (bramka na akcję, nie na intencję). Język-agnostyczny
  z definicji.
- **(D) Park L4** — uznać że twardy gate to L5 (pre-commit), L4 zostaje
  jako sticky reminder bez aspiracji blokowania.

Zasada kciuka od user'a: **"perspektywa zmiany pliku w repo = sage"** —
to outcome-driven framing, sugeruje strongly opcję (C) lub kombinację
(A)+(C).

## Stan po revert

- **Kod / skrypty:** stan repo == 443a7c8 (przed M1).
- **Hooks:** `pre-prompt.sh` istnieje (z poprzedniego cyklu hybrid-levers
  9017249) ale nie jest aktywowany domyślnie — `codex_hooks = false` w
  generate-codex.sh wraca jako default.
- **Planning artifacts:** brief.md, spec.md, plan.md, verification.md,
  manifest.md w tym katalogu — zostają jako historia próby.
- **Decisions.md:** prepended entry o ślepej uliczce.
- **Self-learning:** `b5457470c3e54be3af8a6b45f97c1366` w sage-memory
  zachowuje korektę użytkownika i regułę prewencyjną.
- **Następny cykl:** `20260429-codex-l4-redesign` — wstrzymany. Round 1
  vision już przeprowadzony w konwersacji (5 odpowiedzi user'a).
  Brief nie zapisany — startujemy świeżo gdy user da sygnał.

## Co zostawiamy do reuse w następnym cyklu

Z planning artifacts:
- `brief.md` — analiza enforcement gap, surface levers L1-L5
- `spec.md` — opis ADR-1/2/3/4 i ich trade-offów
- `verification.md` — wzorzec walidacji per-milestone (mechaniczne testy
  + pilot empiryczny)
- Identification of L3 (phase tracker) jako parked future option

Z self-learnings:
- `b5457470c...` — regex-classifier as dead end + outcome vs proxy
- `[LRN:correction] Line-count parity to proxy` — związany wzorzec
- `[LRN:gotcha] Bash 3.2 heredoc apostrophes` — przyda się w każdej
  przyszłej iteracji hooka
- `[PARKED] L3 phase tracker` — alternatywa do rozważenia

## Lekcja procesowa

Pilot empiryczny (test (b) w verification.md) NIE może być deferred do
user'a *po* close-out cyklu. Musi być ostatnim gate'em PRZED tombstone
commit'em. Inaczej "78/78 PASS" daje fałszywe poczucie bezpieczeństwa,
tworzy artefakty kodu, które trzeba potem revertować, i zużywa kapitał
zaufania (deployujemy mechanizm, który zawodzi przy pierwszym kontakcie
z realnym user'em).

**Reguła do uwzględnienia w build/architect workflow:** dla cykli których
outcome jest behavioralny (nie funkcjonalny) — outcome test musi być
gate'em #N+1 PO Gate 8 (Auto-QA), wykonywanym przez user'a, z explicit
[A]/[R] checkpointem. Bez przejścia przez outcome test cykl pozostaje
w `status: implementation-complete-pending-pilot`, NIE w `status: completed`.
