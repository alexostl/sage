---
title: "Plan: Batch 6 subagents, approval boundary, self-learning recall"
status: in-progress
phase: fix-scope-gate
created: 2026-05-14
updated: 2026-05-14
workflow: fix
cycle_id: "20260510-subagent-self-learning-recall-fix"
classification: "Systemic"
---

# Plan: Batch 6 subagents, approval boundary, self-learning recall

## Scope Classification

Ten fix jest `Systemic` według progów `fix.workflow.md`, bo pełna naprawa
dotyka ponad pięciu powierzchni: trzech workflow files, auto-review capability,
Codex generated `AGENTS.md` renderer i stage3 tests. To nadal jest mały
systemic prompt-policy patch, nie przebudowa architektury SageMemory.

## Minimization Pass

Mniejszy wariant byłby możliwy: poprawić tylko Codex `AGENTS.md` renderer i
stage3 tests. To jednak zostawiłoby sprzeczne canonical workflow wording
(`then implement`, `then start building`) oraz auto-review prompt templates bez
memory blocku. Taki patch zamknąłby tylko część objawu.

Wybrany minimalny pełny fix:

- nie zmienia upstream SageMemory;
- nie dodaje nowego modułu ani parsera;
- nie przebudowuje subagent API;
- nie próbuje obsłużyć wszystkich ad-hoc subagent prompts w całym świecie;
- naprawia tylko canonical Sage workflow/capability/generated Codex surfaces,
  które tworzą albo opisują subagent review contract.

## Knowledge Routing Check

Plan został sprawdzony przeciwko świeżemu `alex-os-dev` knowledge-routing
modelowi z 2026-05-13. Ważna korekta: SageMemory nie jest preloadem ani
bezwarunkowym rytuałem "przed każdą pracą". Obowiązuje **targeted recall**:
agent używa memory wtedy, gdy zadanie może zależeć od trwałego kontekstu,
decyzji, encji, preferencji, wcześniejszych korekt albo historii ustaleń.

Konsekwencja dla Batcha 6: subagent prompt policy nie może mówić, że każdy
subagent zawsze ma robić `sage_memory_search` przed pracą. Ma mówić:

- jeśli subagent używa SageMemory, najpierw ustawia/wybiera current project
  (`sage_memory_set_project`); to jest context selection, nie recall ani preload;
- dla Sage-related review/fix/research, gdzie wcześniejsze korekty mogą zmienić
  ocenę, zrób targeted recall;
- self-learning recall używa dokładnie `filter_tags: ["self-learning"]`;
- jeśli recall jest niedostępny, zwykły review może iść dalej z jawnym
  ograniczeniem pewności;
- jeśli trzeba zapisać korektę/self-learning, brak SageMemory jest blockerem
  albo wymaga legalnego `.sage-memory/` fallbacku;
- nie dodawać broad memory preload do generated `AGENTS.md`.

Zapisano self-learning `4a7dc6d1e6854064b6c406ecdd89c0c5`, żeby kolejne cykle
nie wracały do bezwarunkowego "memory before every work".

## OpenAI Docs Verification

Plan został sprawdzony z oficjalnymi OpenAI Codex docs po scope draft. Wnioski:

- Codex subagents są explicit: Codex spawnuje subagenta tylko wtedy, gdy user
  jawnie o to poprosi. To wspiera nasze wymaganie, żeby `[A] Subagent review`
  dosłownie autoryzował spawn, ale nie udawał szerszego approvalu.
- Codex obsługuje built-in agents (`default`, `worker`, `explorer`) i custom
  agents przez `.codex/agents/*.toml`; custom agent może mieć własne
  `developer_instructions`, model i `sandbox_mode`.
- Subagents dziedziczą aktualną sandbox policy parent session, a custom agents
  mogą override'ować sandbox, np. `sandbox_mode = "read-only"`.
- `AGENTS.md` jest ładowany przy starcie run/session przez chain global →
  project → nested directory, z limitem rozmiaru (`project_doc_max_bytes`).
  To wzmacnia minimization pass: generated Codex guidance musi być krótki,
  a szczegółowe prompt-policy powinno żyć w workflow/capability files.

Konsekwencja dla planu: w tym batchu "read-only subagent" oznacza przede
wszystkim kontrakt promptowy i review-role boundary, chyba że osobno
skonfigurujemy custom agent z `sandbox_mode = "read-only"`. Ten batch nie
tworzy custom agent config, więc wording nie może obiecywać sandbox-enforced
read-only isolation.

## Files To Change

### Source And Test Surfaces

1. `core/workflows/fix.workflow.md`
   - Zmienić `[A] Subagent review` wording na read-only review + return to
     checkpoint/decision, bez `then implement` i bez sugerowania approvalu
     kolejnego etapu.
   - Doprecyzować, że po findings decyzja wraca do użytkownika; `[A]` nie jest
     approvalem root cause ani planu.

2. `core/workflows/build.workflow.md`
   - Usunąć z `[A] Subagent review` frazy sugerujące automatyczne przejście:
     `then continue to plan`, `then start building`.
   - Zachować osobne ścieżki `[A] Subagent review`, `[S] Skip review`, `[C]`,
     `[F]`; nie zmieniać semantyki scoped autonomy po zatwierdzonym planie.

3. `core/workflows/architect.workflow.md`
   - Analogicznie usunąć `then continue to plan` i `then start milestone 1`
     z `[A] Subagent review`.
   - Zachować read-only review jako advisory step przed decyzją użytkownika.

4. `core/capabilities/review/auto-review/SKILL.md`
   - Zmienić generic `[A] Review — sub-agent reviews, then proceed` na
     wording, który mówi: sub-agent reviews, findings are shown, user decides.
   - Doprecyzować, że read-only jest review-role/prompt contract, a sandbox-level
     read-only wymaga Codex custom agent config lub runtime sandbox support poza
     tym patchem.
   - Dodać canonical "Targeted Recall For Subagent Review" prompt block do
     sub-agent prompt instructions:
     - do not preload memory for every task;
     - before any SageMemory operation, set/select the current project;
     - use targeted project/domain recall only when durable context may matter;
     - search self-learning with `filter_tags: ["self-learning"]` when prior
       corrections/gotchas could affect the review;
     - if tools are unavailable, read `.sage-memory/self-learning.md` only when
       the project provides it, or report fallback unavailable;
     - report which prevention rules affected review when self-learning recall
       was used.
   - Dopisać językowy kontrakt: natural-language prose może być po polsku for
     Alex handoff prompts, ale canonical identifiers/paths/tool names/raw
     evidence zostają verbatim.

5. `runtime/platforms/codex/setup/lib/agents-md.sh`
   - Doprecyzować Rule 1A / subagent section dla Codex generated `AGENTS.md`:
     subagent/reviewer prompts muszą dostać Sage scope, MCP/tool expectations
     oraz targeted-recall contract z `filter_tags: ["self-learning"]` dla
     self-learning, bez broad memory preload.
   - Nie rozpychać zawsze ładowanego `AGENTS.md` ponad potrzebę; krótki blok,
     szczegóły w workflow/capability files.

6. `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
   - Dodać regression tests dla generated Codex guidance:
     - obecny jest `filter_tags: ["self-learning"]`;
     - obecny jest fallback `.sage-memory/self-learning.md`;
     - obecne jest raportowanie prevention rules;
     - nie ma `filter_tags: ["learning"]` jako self-learning query;
     - `[A] Subagent review` zachowuje read-only authorization i nie sugeruje
       generic approval.

7. `runtime/platforms/codex/setup/tests/subagent-review-policy.bats`
   - Dodać source-level regression tests dla canonical workflow/capability
     surfaces, niezależnie od wygenerowanego `AGENTS.md`.
   - Test ma sprawdzać `core/workflows/fix.workflow.md`,
     `core/workflows/build.workflow.md`, `core/workflows/architect.workflow.md`
     i `core/capabilities/review/auto-review/SKILL.md`.
   - Test ma failować na starym `[A] Subagent review` wording:
     `then implement`, `then start building`, `then continue to plan`,
     `then proceed` w subagent-review approval context.
   - Test ma pilnować, że `[S] Skip review`, `[C] Checkpointed implementation`
     i `[F] Full autonomous implementation` zostają osobnymi ścieżkami tam,
     gdzie workflow je posiada.
   - Test ma pilnować auto-review prompt source: targeted recall zamiast broad
     preload, `sage_memory_set_project` przed SageMemory use,
     `filter_tags: ["self-learning"]`, `.sage-memory/self-learning.md` fallback
     i reporting `prevention rules`.

### Bookkeeping Surfaces

8. `.sage/work/20260510-subagent-self-learning-recall-fix/*`,
   `.sage/work/20260510-subagent-review-approval-boundary-fix/*`,
   `.sage/decisions.md`
   - Utrzymać anchor/sibling bookkeeping, verification i closeout.

## Tests

1. Najpierw dodać failing source-level text tests w
   `runtime/platforms/codex/setup/tests/subagent-review-policy.bats`.
   Expected initial failure:
   - canonical workflow sources nadal zawierają stare `[A]` wording:
     `then implement`, `then start building`, `then continue to plan`,
     `then proceed` w subagent-review approval context;
   - source-level tests nie mają jeszcze gwarancji, że `[S]`, `[C]`, `[F]`
     pozostają osobnymi approval/autonomy paths;
   - `auto-review/SKILL.md` nie ma jeszcze targeted recall blocku z
     `sage_memory_set_project`, `filter_tags: ["self-learning"]`, fallbackiem
     i prevention-rules reporting.

2. Dodać failing stage3 testy w
   `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`.
   Expected initial failure: generated `AGENTS.md` nie zawiera compact targeted
   recall contractu i nie pilnuje braku broad preload.

3. Po implementacji uruchomić:

```bash
bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
```

4. Uruchomić szerszy relevant subset, żeby złapać regressions generated
   `AGENTS.md` i hook/codex setup contract:

```bash
bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats \
  runtime/platforms/codex/setup/tests/stage3-agents-md.bats \
  runtime/platforms/codex/setup/tests/alex-native-core-text.bats
```

5. Uruchomić workflow/capability static validator:

```bash
bash develop/validators/contracts/validate-workflows.sh
```

6. Uruchomić static checks:

```bash
bash -n runtime/platforms/codex/setup/lib/agents-md.sh
git diff --check .sage/work/20260510-subagent-self-learning-recall-fix/plan.md \
  .sage/decisions.md
```

## Rollback

Rollback jest prosty: odwrócić zmiany w siedmiu source/test files oraz w
artefaktach cyklu. Nie ma migracji, cache rewrite ani zmiany danych
SageMemory.

## Risks

- Zbyt mocne usunięcie `then proceed` może sprawić, że workflow będzie mniej
  ergonomiczny po czystym PASS. Mitigacja: wording ma mówić, że findings są
  pokazane i użytkownik decyduje; ścieżki `[S]`, `[C]`, `[F]` nadal istnieją.
- Dodanie memory blocku może zwiększyć prompt surface albo wrócić do
  niechcianego preloadu. Mitigacja: blok mówi targeted recall, nie
  unconditional `sage_memory_search before work`; generated Codex `AGENTS.md`
  dostaje zwięzły kontrakt.
- Testy tekstowe mogą być kruche. Mitigacja: sprawdzać krótkie canonical
  phrases (`filter_tags: ["self-learning"]`, `.sage-memory/self-learning.md`,
  `prevention rules`) zamiast całych akapitów.
- Możemy obiecać silniejsze read-only guarantees niż Codex zapewnia przez sam
  prompt. Mitigacja: wording rozróżnia promptowy review-role contract od
  sandbox-enforced read-only custom agent config.

## Done Criteria

- `[A] Subagent review` wording nie sugeruje, że sam review approval uruchamia
  implementację.
- Source-level tests obejmują canonical workflow/auto-review source surfaces,
  nie tylko generated `AGENTS.md`.
- Regression tests łapią stare `[A]` wording: `then implement`,
  `then start building`, `then continue to plan`, `then proceed` w
  subagent-review approval context.
- Regression tests pilnują, że `[S]`, `[C]`, `[F]` pozostają osobnymi ścieżkami
  tam, gdzie workflow je posiada.
- Auto-review prompt policy wymaga targeted recall wtedy, gdy durable context
  lub self-learning corrections mogą wpłynąć na review; nie wymaga broad memory
  preloadu.
- Codex generated `AGENTS.md` zawiera compact targeted recall contract.
- Regression tests łapią brak canonical `filter_tags: ["self-learning"]`,
  fallbacku i prevention-rules reporting.
- Relevant Bats subset, `bash -n` i `git diff --check` przechodzą.
