---
cycle_id: "20260510-cluster-d-alex-native-visibility-fix"
artifact: plan
status: implemented
created: 2026-05-10
updated: 2026-05-10
---

# Plan - klaster D

## Classification

**Systemic fix accepted as fix.** Zmiana dotyka więcej niż 5 plików, ale
zostaje w `/sage:fix`, bo jest spójną poprawką instrukcji/procesu, a nie nową
architekturą runtime.

## Task 1 - Alex-readable explanations

**Design constraint:**

Nie dublować wzorca komunikacyjnego w wielu gorących instrukcjach naraz.
Token load i szum informacyjny dla agenta mają zostać możliwie małe. Preferuj
jedno krótkie źródło kontraktu i test/generator, który pilnuje, że trafia tam,
gdzie jest potrzebny.

**Files:**

- Preferowane pojedyncze źródło: istniejąca Alex-native sekcja w
  `core/constitution/sage-process.constitution.md` albo generatorowa sekcja
  `runtime/platforms/codex/setup/lib/agents-md.sh`, jeśli to jest faktyczne
  źródło emitowane do generated `AGENTS.md`.
- `AGENTS.md` tylko jako generated/selfhost output do weryfikacji albo
  regeneracji, nie jako osobne miejsce ręcznego dopisywania tej samej reguły.
- `core/capabilities/orchestration/sage-navigator/SKILL.md` tylko jeśli analiza
  pokaże, że kontrakt musi żyć przy routing/checkpoint wording, a nie wystarczy
  wspólna sekcja Alex-native.
- `core/workflows/*.workflow.md` tylko dla miejsc, które faktycznie produkują
  user-facing artifacts albo checkpoint prose.
- `runtime/platforms/codex/setup/tests/**` dla regresji tekstowej.

**Change:**

Dodać krótki wzorzec komunikacyjny tylko raz: najpierw proste zdanie co się
dzieje, potem dlaczego to problem, potem techniczna nazwa w backtickach, na
końcu co zmieniamy. Nazwy techniczne zostają, ale nie są jedynym wyjaśnieniem.
Jeśli ta sama treść miałaby trafić do dwóch miejsc, wybrać miejsce bliższe
źródłu generowania i usunąć duplikat z planu implementacji.

**Tests:**

Regresja tekstowa ma potwierdzić obecność kontraktu w finalnej powierzchni,
ale nie wymuszać wielu kopii tej samej treści. Test powinien raczej pilnować
minimalnego efektu niż dokładnego, rozbudowanego paragrafu.

## Task 2 - Workflow artifact language contract

**Files:**

- `core/workflows/*.workflow.md`
- `develop/templates/qa-report-template.md` tylko jeśli wspólny workflow
  contract nie wystarczy albo template wymaga ostrzeżenia

**Change:**

Minimalnie dopisać do workflowów zasadę: nowa proza artefaktów Sage podąża za
językiem projektu. W tym repo oznacza to polski tekst objaśniający, ale
angielskie zostają:

- artifact filenames;
- frontmatter keys;
- `status`, `phase`, `workflow` i inne wartości Sage-specific, jeżeli są
  kanoniczne;
- command names, ścieżki, identyfikatory techniczne;
- raw test output, logi i cytaty z narzędzi.

Nie tłumaczymy formatów maszynowych ani nazw stanów Sage.

**Tests:**

Najpierw sprawdzić istniejące testy generatora/instrukcji. Jeśli nie ma
dobrego miejsca na wszystkie workflowy, dodać wąską regresję tekstową dla
generated Codex/Alex-native contract zamiast testować każdy workflow osobno.

## Task 3 - Codex task-plan visibility analysis

**Files:**

- `.sage/work/20260510-cluster-d-alex-native-visibility-fix/visibility-analysis.md`
- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `core/workflows/*.workflow.md` tylko po analizie
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/**`

**Change:**

Najpierw zapisać krótką analizę oficjalnych OpenAI docs i lokalnego Codex
behavior:

- `turn/plan/updated` istnieje jako App Server event;
- `/plan` jest CLI mode, nie bezpośrednio tym samym co `update_plan`;
- plan/progress może być zależny od klienta, więc Sage powinien wymagać
  zachowania agenta, a nie obiecywać konkretnego UI w każdym runtime;
- ustalić próg: Standard+ work powinien używać krótkiego planu 3-6 kroków,
  ale read-only rozmowy i lekkie pytania nie powinny tego robić.

Po analizie dopisać minimalny contract, jeśli potwierdzi się bezpieczna
powierzchnia.

**Subagent option:**

Przy checkpointcie można wybrać `[A] Subagent review`, co jawnie autoryzuje
Codex do spawnowania read-only subagenta. Subagent ma wtedy sprawdzić tylko
oficjalne OpenAI docs i lokalne evidence dla plan/progress visibility.

## Verification

- Uruchomić relevant Bats tests dla Codex setup/generatora, zwłaszcza Stage 3
  generated `AGENTS.md` tests.
- Uruchomić dodatkowy `rg` audit po workflowach, żeby sprawdzić, czy kontrakt
  językowy jest wspólny i nie rozjeżdża się między workflowami.
- Jeśli zmiany dotkną generated output, uruchomić generator smoke dla targetu
  tymczasowego.

## Rollback

Revert jest prosty: cofnąć zmiany instrukcji/generatora/testów i zostawić
artefakty cyklu jako zapis decyzji. Nie ma migracji danych ani zmian runtime
API.
