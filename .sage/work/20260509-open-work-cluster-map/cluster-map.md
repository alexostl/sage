---
cycle_id: "20260509-open-work-cluster-map"
title: "Mapa klastrów otwartych prac Sage"
workflow: analyze
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
---

# Mapa klastrów otwartych prac Sage

## Cel

Ta mapa jest orientacyjnym wejściem dla kolejnych agentów. Otwarte intake'y mają
być traktowane jako większe batche wykonawcze, a nie jako lista samotnych
fixów. Alex zdecydował 2026-05-13, że kolejne cykle mają iść w kolejności
zapisanej niżej.

## Batch 1 - Formalne wejście i wznowienie workflow

**Cel:** rozmowa, status artefaktów Sage i widok Codexa mają mówić to samo:
czy cykl naprawdę istnieje, czy został wznowiony i jakie bramki obowiązują.

**Wątki źródłowe:**

- `20260509-cycle-workflow-entry-enforcement-fix`
- `20260509-agent-resume-intake-cycle-fix`
- `20260509-cycle-state-disclosure-fix`
- `20260509-codex-task-plan-visibility-fix`
- `20260509-fix-trigger-gate-fix`
- `20260509-active-cycle-lease-lock`

**Dlaczego razem:** to jest jeden problem graniczny. Agent nie może tylko
powiedzieć, że wchodzi w workflow; musi utworzyć albo wznowić formalny stan na
dysku, pokazać go użytkownikowi i respektować odpowiedni gate. Lease lock jest
częścią tego samego modelu ownership: aktywny cykl blokuje implementację i
artefakty aktywnego cyklu innej sesji, ale nie powinien blokować równoległej
pracy koncepcyjnej w osobnych `.sage/work/*` intake/paused cycles.

**Pierwszy sensowny krok:** rozpocząć `/sage:fix` od diagnozy entry/resume
contract: pewna klasyfikacja Standard+ tworzy albo wznawia cykl; fix-trigger
wchodzi przez diagnose/scope gate; Codex `update_plan` pokazuje żywy postęp
tam, gdzie praca jest Standard+. W tym samym cyklu doprecyzować predicate:
allow capture/planning-only `.sage/**` dla osobnych intake/paused cycles, block
implementation paths oraz aktywny `in-progress` cycle innej sesji.

## Batch 2 - Hook recovery i mutation preflight

**Cel:** agent ma sprawdzać zamiar mutacji przed zapisem i umieć legalnie
odzyskać pracę po bloku hooka, bez obchodzenia zakresu albo kończenia
niepełnego fixa.

**Wątki źródłowe:**

- `20260510-mutation-intent-preflight-gap`
- `20260509-file-change-enforcement-fix`
- `20260509-binary-asset-mutation-contract-fix`
- `20260512-hook-recovery-scope-amputation-fix`
- `20260509-hook-block-recovery-behavior-fix`
- `20260509-blocking-hook-guidance-review`

**Dlaczego razem:** `apply_patch`, native `file_change`, mutujący Bash/git i
binarne assety są różnymi powierzchniami tego samego ryzyka: repo może zostać
zmienione zanim Sage potwierdzi aktywny cykl, scope i threshold. Hook block ma
prowadzić do legalnej ścieżki recovery, nie do amputacji potrzebnego pliku.

**Pierwszy sensowny krok:** zdiagnozować wszystkie mutujące tool surfaces i
ustalić kontrakt preflight: active cycle, claimed scope, file count, workflow
threshold, closeout state, a potem dopiero zapis.

## Batch 3 - Closeout, handoff i dokumentacja po końcu cyklu

**Cel:** zamknięcie cyklu ma być ostatnią mutacją, a lokalny handoff po
zamknięciu nie może dopisywać kolejnego epilogu do artefaktów Sage.

**Wątki źródłowe:**

- `20260509-closeout-documentation-mutation-model`
- `20260510-closeout-ordering-workflow-hook-fix`
- `20260510-post-closeout-handoff-doc-mutation-fix`
- `20260513-post-closeout-git-next-step-build`
- `20260513-lightweight-repo-hygiene-decisions-fix`

**Dlaczego razem:** wszystkie trzy dotyczą tej samej granicy: kiedy cykl jeszcze
żyje i można porządkować plan/QA/decisions, a kiedy jest już materiałem do
commita albo handoffu. Git next-step jest naturalnym końcem tego samego
rytuału: po closeoucie agent powinien jasno powiedzieć, czy stage/commit/push
zostały wykonane, i zapytać o git handoff, zamiast zostawiać to Alexowi do
pamiętania. Lightweight repo hygiene, np. pojedynczy `.gitignore`, jest tą
samą granicą: nie powinien rozszerzać zamkniętego cyklu, ale nie zawsze
zasługuje na osobny manifest zamiast krótkiej decyzji.

**Pierwszy sensowny krok:** ujednolicić closeout guidance we workflowach:
final self-review przed statusem completed, decyzje/QA/plan przed zamknięciem,
manifest closeout jako ostatnia zmiana. Następnie doprecyzować post-closeout
git next-step: status stage/commit/push i pytanie o handoff zmian bieżącego
cyklu. Dodać regułę `decisions-only repo hygiene`: pojedyncza, oczywista
zmiana repo hygiene może wymagać wpisu w `.sage/decisions.md`, ale nie pełnego
manifestu, jeśli nie dotyka runtime, hooków, workflowów, testów, builda,
security ani release packaging.

## Batch 4 - Codex surface, loader i instruction reachability

**Cel:** Codex ma docierać do właściwych instrukcji Sage przez poprawne loader
stuby, świeży navigator, jednoznaczne entrypointy i aktualną flagę hooks.

**Wątki źródłowe:**

- `20260509-duplicate-sage-entrypoint-fix`
- `20260509-sage-navigator-skill-drift-fix`
- `20260509-selfhost-codex-loader-path-fix`
- `20260509-codex-hooks-feature-flag-migration-fix`

**Dlaczego razem:** to są problemy reachability. Jeśli loader wskazuje złą
ścieżkę, navigator driftuje albo config używa starej flagi, agent może nie
wczytać poprawnego workflow albo hooków.

**Pierwszy sensowny krok:** zacząć od różnicy selfhost vs target loader paths,
potem uporządkować navigator/entrypointy i migrację `codex_hooks` -> `hooks`.

## Batch 5 - Harness, incidents i language-invariant matching

**Cel:** testy, incidenty i harness mają sprawdzać rzeczywisty stan oraz sens
zachowania, a nie przypadkowe stare dirty files albo jedną angielską frazę.

**Wątki źródłowe:**

- `20260509-mcp-incident-followup-fixes`
- `20260510-language-invariant-workflow-matching-fix`
- `20260509-target-repo-ownership-harness-fix`

**Dlaczego razem:** wszystkie trzy rozdzielają prawdziwy sygnał od szumu:
stary worktree nie powinien produkować false positives, a transcript assertions
nie powinny oblewać semantycznie poprawnej pracy tylko dlatego, że agent mówi po
polsku albo sam skorygował transient drift.

**Pierwszy sensowny krok:** podzielić matching na structural/deterministic oraz
semantic/natural-language. Dla natural language używać stanu, eventów albo
language-invariant klasyfikacji zamiast regexów po angielskiej frazie.

## Batch 6 - Subagenci, approval boundary i self-learning recall

**Cel:** subagent ma dostać jawne granice approval oraz obowiązek recallu
self-learning, zamiast dziedziczyć je przypadkiem z kontekstu głównego agenta.

**Wątki źródłowe:**

- `20260510-subagent-review-approval-boundary-fix`
- `20260510-subagent-self-learning-recall-fix`

**Dlaczego razem:** oba fixy dotyczą delegacji. Subagent review nie zatwierdza
automatycznie implementacji, a subagent bez memory recall może powtórzyć
skorygowane już błędy.

**Pierwszy sensowny krok:** poprawić wording opcji subagent review i dodać
kanoniczny prompt fragment wymagający `sage_memory_set_project` oraz recallu
`self-learning` przed pracą subagenta.

## Batch 7 - Alex-native komunikacja i polska proza

**Cel:** Sage ma tłumaczyć skutki i przyczyny prostym językiem dla Alexa oraz
pisać nową prozę `.sage` po polsku.

**Wątki źródłowe:**

- `20260509-alex-readable-change-explanations-fix`
- `20260509-qa-workflow-polish-report-contract`

**Dlaczego razem:** to jedna warstwa UX języka. Nazwy techniczne mogą zostać,
ale agent powinien najpierw powiedzieć, co się dzieje, czemu to problem i co
trzeba zmienić.

**Pierwszy sensowny krok:** dodać do workflow/generated Codex contract wzorzec:
"co się dzieje" -> "czemu to problem" -> "jak to się technicznie nazywa" ->
"co trzeba zmienić"; QA raporty mają używać polskiej prozy.

## Batch 8 - Worktree lifecycle i SageMemory

**Cel:** port Codexa ma mieć procedurę pracy na worktree: tworzenie, closeout,
handoff, lokalna integracja, sprzątanie/likwidacja oraz bezpieczny model pamięci
projektowej.

**Wątki źródłowe:**

- `20260510-codex-worktree-support-build`
- `20260510-manual-sagememory-worktree-repair`

**Dlaczego razem:** `manual-sagememory-worktree-repair` nie powinien zostać
samotnym fixem. To część szerszego problemu: worktree agent i integrator muszą
wiedzieć, gdzie żyją artefakty, co wchodzi do Git, co zostaje lokalne, jak nie
zgubić project memory i jak bezpiecznie domknąć albo usunąć worktree.

**Pierwszy sensowny krok:** rozpocząć od `20260510-codex-worktree-support-build`
i w specu jawnie podpiąć repair SageMemory jako zależny etap albo osobny krok
w tym samym lifecycle batchu. Jeśli pełne scalanie `.sage-memory` okaże się
ryzykowne, wydzielić je jako gated sub-fix z backupem i explicit approval.

## Kolejność obowiązująca

1. **Batch 1 - Formalne wejście i wznowienie workflow**
2. **Batch 2 - Hook recovery i mutation preflight**
3. **Batch 3 - Closeout, handoff i dokumentacja po końcu cyklu**
4. **Batch 4 - Codex surface, loader i instruction reachability**
5. **Batch 5 - Harness, incidents i language-invariant matching**
6. **Batch 6 - Subagenci, approval boundary i self-learning recall**
7. **Batch 7 - Alex-native komunikacja i polska proza**
8. **Batch 8 - Worktree lifecycle i SageMemory**

## Reguła dla kolejnych agentów

Nie zaczynać od pojedynczego intake'u bez sprawdzenia tej mapy. Jeśli intake
należy do batcha, nowy `/sage:fix` albo `/sage:build` powinien jawnie wskazać,
czy robi cały batch, jego etap, czy świadomie wycina wąski surgical fix z
batcha.
