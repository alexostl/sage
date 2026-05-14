---
cycle_id: "20260510-subagent-self-learning-recall-fix"
title: "Fix: subagenci musza jawnie robic self-learning recall"
workflow: fix
phase: verify
status: completed
created: 2026-05-10
updated: 2026-05-14
owner: alexostl
needs-triage: false
priority: P1
semantic_reclassification: accepted
source: "conversation"
suggested_workflow: fix
batch: 6
batch_anchor: true
related:
  - ".sage/work/20260510-subagent-review-approval-boundary-fix/manifest.md"
  - "AGENTS.md"
  - ".sage-memory/memory.db"
  - ".sage-memory/self-learning.md"
  - "core/workflows/**"
  - "core/capabilities/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
  - ".codex/sessions/2026/05/10/rollout-2026-05-10T09-36-09-019e10d0-a5a2-7a33-9c9d-5d7b1514b6f6.jsonl"
  - ".codex/sessions/2026/05/09/rollout-2026-05-09T23-59-29-019e0ec0-b0f4-7482-a92e-30ad16c33d3f.jsonl"
scope:
  - ".sage/work/20260510-subagent-self-learning-recall-fix/*"
  - ".sage/work/20260510-subagent-review-approval-boundary-fix/*"
  - ".sage/decisions.md"
  - "AGENTS.md"
  - "core/workflows/**"
  - "core/capabilities/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: subagenci musza jawnie robic self-learning recall

## State

**Current phase:** verify. Status `completed`; Alex approved completion, commit,
and push.

**Next step:** Commit and push the approved changes.

**Batch 6 active state (2026-05-14):** Root cause zapisany w
`root-cause.md` i zaakceptowany przez Alexa przez `[S] Skip review`; fix scope
plan zostal zrewidowany po auto-review i zatwierdzony przez Alexa przez
`[S] Skip review`. Implementacja i focused verification sa zakonczone; Alex
approved completion, commit, and push.

## Finding

Audit ostatnich watkow `sage-selfhost` z subagentami pokazal, ze SageMemory
dziala poprawnie jako store/search, ale Sage SelfHost uzywa go niespojnie:

- glowni agenci coraz czesciej robia `sage_memory_set_project` i
  `sage_memory_search` przed praca;
- subagenci review/fix czesto dostaja prompt bez jawnego wymogu SageMemory
  recall;
- `fork_context=true` czasem przenosi wynik recallu glownego agenta, ale
  `fork_context=false` oznacza zimny start bez self-learning corrections;
- w jednym najnowszym watku agent zapytal o learningi z
  `filter_tags: ["learning"]` zamiast kanonicznego
  `filter_tags: ["self-learning"]`, przez co query zwrocilo pusty wynik mimo
  istniejacych relevantnych wpisow.

To jest bug po stronie Sage SelfHost prompt policy / generated instructions,
nie bug upstream SageMemory. SageMemory poprawnie wykonalo bledne zapytanie.

## Desired behavior

Dla Standard+ pracy i kazdego subagenta review/fix/research zwiazanego z Sage:

- glowny agent przed spawnem robi project/domain recall oraz self-learning
  recall z `filter_tags: ["self-learning"]`;
- subagent prompt zawiera jawna instrukcje: jesli narzedzia SageMemory sa
  dostepne, ustaw projekt i wyszukaj relevantne self-learning corrections
  przed review; jesli narzedzia nie sa dostepne, uzyj fallbacku
  `.sage-memory/self-learning.md` lub raportuj brak dostepu;
- jesli subagent prompt jest tworzony przez agenta robiacego handoff dla Alexa,
  natural-language prose promptu ma byc po polsku. Struktura, komendy, sciezki,
  frontmatter keys, narzedzia i raw evidence zostaja kanoniczne/verbatim;
- subagent raportuje, jakie learningi/prevention rules wplynely na ocene;
- `filter_tags: ["learning"]` nie jest traktowane jako poprawny zamiennik
  `["self-learning"]`.

## Prompt fixes to implement

Ten intake obejmuje dwie male poprawki prompt-policy, ktore powinny byc
wdrozone razem:

1. **Kanoniczny self-learning query prompt:** wszystkie instrukcje dla agentow,
   ktore mowia o self-learning recall, musza uzywac dokladnie
   `filter_tags: ["self-learning"]`. Nie wolno zamieniac tego na
   `tags: ["self-learning"]`, `filter_tags: ["learning"]` ani ogolne
   "learning".
2. **Subagent recall prompt block:** kazdy prompt dla subagenta review/fix/
   research powinien zawierac jawny blok:
   "Before reviewing, use SageMemory if available: set project, search project
   context, then search self-learning with `filter_tags: [\"self-learning\"]`.
   If tools are unavailable, read `.sage-memory/self-learning.md` or report
   that memory fallback was unavailable. In your report, state which
   prevention rules affected your review."
3. **Polski handoff prompt dla subagenta:** jesli glowny agent deleguje
   subagentowi review/fix/research w ramach handoffu dla Alexa, instrukcja
   natural-language ma byc po polsku. Nie tlumaczyc canonical identifiers:
   `filter_tags: ["self-learning"]`, sciezek, command names, frontmatter keys,
   tool names, quoted evidence ani raw outputow.

## Candidate scope

- Ustalic, gdzie Sage generuje instrukcje dla auto-review/subagent prompts
  albo workflow guidance dla subagentow.
- Dopisac kanoniczny blok "Memory Before Subagent Review" do odpowiednich
  workflow/capability templates.
- Dopisac kontrakt jezykowy dla promptow subagentow tworzonych przy handoffie:
  polska proza dla Alexa, canonical technical terms bez tlumaczenia.
- Upewnic sie, ze template/prompt glownych agentow przekazuje ten blok takze
  przy `fork_context=false`, gdzie subagent nie dziedziczy recallu glownego
  agenta.
- Dodac test tekstowy/regresyjny, ktory wykrywa:
  - brak `filter_tags: ["self-learning"]` w generated subagent guidance;
  - uzycie `filter_tags: ["learning"]` jako self-learning query;
  - brak fallbacku do `.sage-memory/self-learning.md` przy niedostepnym MCP.
- Przejrzec czy `AGENTS.md` Rule 1A wymaga doprecyzowania dla subagentow.

## Boundary

Ten intake nie zmienia upstream SageMemory i nie zaklada zmiany schematu tagow.
Tag kanoniczny pozostaje `self-learning`. Ewentualne aliasy typu `learning`
moglyby byc osobnym pomyslem, ale nie sa wymagane do naprawy observed bug.
