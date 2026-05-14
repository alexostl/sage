---
title: "Root cause: Batch 6 subagents, approval boundary, self-learning recall"
status: in-progress
phase: root-cause-gate
created: 2026-05-14
updated: 2026-05-14
workflow: fix
cycle_id: "20260510-subagent-self-learning-recall-fix"
---

# Root cause: Batch 6 subagents, approval boundary, self-learning recall

## Summary

Batch 6 ma jedną wspólną przyczynę: Sage ma kilka miejsc, które mówią o
subagent review i memory recall, ale nie mają jednego kanonicznego kontraktu
dla delegacji. To są dwa sprzężone pod-problemy:

1. **Approval boundary:** `[A] Subagent review` autoryzuje read-only review,
   ale checkpoint wording w kilku workflow nadal sugeruje automatyczne przejście
   dalej po review.
2. **Subagent memory recall:** auto-review prompt templates są read-only, ale
   nie wymagają własnego SageMemory recallu ani raportowania, które
   self-learning rules wpłynęły na ocenę.

To nie wygląda na bug w upstream SageMemory. `core/constitution` i część
generatorów znają kanoniczne `filter_tags ["self-learning"]`; problem jest w
tym, że auto-review prompt surface i Codex generated guidance nie przenoszą
tego kontraktu do delegowanych subagentów.

## Evidence

### Approval boundary evidence

1. `core/workflows/fix.workflow.md` miesza review z przejściem dalej. Root
   cause gate mówi `to verify diagnosis, then proceed`, a fix scope gate mówi
   `to review the fix plan, then implement`. Ten drugi wording tworzy ryzyko
   z intake'u: subagent review może zostać potraktowany jako approval
   implementacji.

2. Ten sam wzorzec istnieje w `build` i `architect`: spec/design review mówi
   `then continue to plan`, a plan review mówi `then start building` albo
   `then start milestone 1`. To pokazuje, że problem jest systemowy na
   poziomie workflow checkpoint wording, nie jednorazowy w fix workflow.

3. `core/capabilities/review/auto-review/SKILL.md` definiuje auto-review jako
   `[A] Review — sub-agent reviews, then proceed` i mówi, że po wybraniu `[A]`
   workflow musi run auto-review before proceeding. Jednocześnie niżej słusznie
   mówi, że subagent jest tylko read-only i "The user decides what to do with
   findings." Te dwie instrukcje ciągną w różne strony: capability zna granicę
   decyzyjną, ale checkpoint surface nadal brzmi jak zgoda na kolejny etap.

### Memory recall evidence

4. Auto-review prompt templates są read-only, ale nie zawierają bloku:
   `set project`, `search project/domain memory`, `search self-learning with
   filter_tags: ["self-learning"]`, fallback do `.sage-memory/self-learning.md`
   ani wymogu raportowania prevention rules. To tłumaczy, czemu subagent może
   zacząć z zimnym kontekstem, zwłaszcza przy `fork_context=false`.

5. Codex `AGENTS.md` renderer mówi tylko "Search project/domain memory and
   self-learning corrections." Brakuje tam dokładnej kanonicznej formy
   `filter_tags: ["self-learning"]`, mimo że `core/constitution` i Claude Code
   generator ją mają. Stage3 tests sprawdzają explicit authorization i scope
   inheritance, ale nie sprawdzają ani memory blocku dla subagentów, ani zakazu
   błędnego `filter_tags: ["learning"]`, ani fallbacku do
   `.sage-memory/self-learning.md`.

6. Konkretne source refs dla kanonicznego recallu istnieją poza Codex
   generated guidance: `core/constitution/sage-process.constitution.md` wymaga
   self-learning search z `filter_tags ["self-learning"]`, a
   `runtime/platforms/claude-code/setup/generate-claude-code.sh` używa tej
   formy w build/fix preambles. To potwierdza, że brak jest po stronie Codex
   subagent/generator surface, nie w tag modelu SageMemory.

### Transcript evidence boundary

Manifest wskazywał stare `.codex/sessions/...` ścieżki pod repo, ale tych
plików nie ma w working tree. Globalne `~/.codex/sessions/2026/05/10` pokazuje
ogólne przypadki subagent prompts i memory recall, ale nie daje pełnego,
jednego chainu: "prompt bez recall blocku → brak self-learning recallu →
błędna ocena". Dlatego diagnoza po rewizji nie opiera się na pełnym incident
transcript. Reprodukcja powinna być regression testem source/generator surface:
czy generated guidance i auto-review prompts zawierają wymagany kontrakt oraz
czy nie sugerują automatycznego przejścia do implementacji po `[A]`.

## Chain

Główny agent widzi checkpoint `[A] Subagent review` i legalnie spawnuje
read-only subagenta. Istniejący prompt subagenta mocno mówi "nie edytuj", ale
nie mówi "zrób własny project + self-learning recall". To znaczy, że poprawne
zachowanie zależy od przypadkowego kontekstu: główny agent mógł zrobić recall,
subagent mógł odziedziczyć go przez fork, albo nie.

Po powrocie subagenta drugi problem uderza w granicę approval: checkpoint
wording `then proceed` / `then implement` brzmi jak zgoda na kolejny etap,
chociaż sam subagent review jest tylko dowodem doradczym. Jeśli review zwróci
findings, decyzja musi wrócić do Alexa; `[A]` nie jest approvalem root cause,
planu ani implementacji.

## Root Cause

Root cause: kontrakt delegacji subagentów jest rozproszony między workflow
checkpoint wording, auto-review capability prompts i generated Codex
instructions. Brakuje dwóch jawnych kontraktów na tej samej granicy:

- `[A] Subagent review` autoryzuje tylko read-only review i prezentację findings
  użytkownikowi; nie zatwierdza root cause, planu ani implementacji;
- każdy Sage-related review subagent musi dostać "Memory Before Subagent
  Review": project selection, project/domain recall, self-learning recall przez
  `filter_tags: ["self-learning"]`, fallback do `.sage-memory/self-learning.md`
  i raport prevention rules.

## Confidence

High for source-level prompt-policy gap. Medium for runtime incident chain,
bo nie mamy jednego kompletnego transcriptu pokazującego cały sequence od braku
recallu do złej oceny. To wystarcza do source fixu, bo regression targetem są
workflow/capability/generator contracts, nie pojedynczy log.

## Fix Direction

Minimalny fix powinien:

- zmienić checkpoint wording `[A] Subagent review`, żeby autoryzował read-only
  review i powrót z findings do checkpointu, bez fraz typu `then implement`;
- dodać kanoniczny "Memory Before Subagent Review" block do auto-review prompt
  policy, z dokładnym `filter_tags: ["self-learning"]`, fallbackiem do
  `.sage-memory/self-learning.md` i raportem prevention rules;
- doprecyzować generated Codex guidance dla subagentów, bez dużego rozszerzania
  zawsze ładowanego `AGENTS.md`;
- dodać stage3/text regression tests dla subagent memory blocku, exact
  `filter_tags: ["self-learning"]`, fallbacku i braku `filter_tags: ["learning"]`.

## Scope Classification

Systemic by fix workflow threshold if we repair all affected checkpoint
surfaces in one pass: likely `fix.workflow.md`, `build.workflow.md`,
`architect.workflow.md`, `core/capabilities/review/auto-review/SKILL.md`,
`runtime/platforms/codex/setup/lib/agents-md.sh`, and
`runtime/platforms/codex/setup/tests/stage3-agents-md.bats`.

This does not require a new architecture or upstream SageMemory change, but it
does cross the `5+ files changed` threshold. The fix-scope gate should either:

1. proceed as a Systemic fix with explicit approval, or
2. narrow Batch 6 to a smaller first patch and split remaining surfaces into
   follow-up intake.
