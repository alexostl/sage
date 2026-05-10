---
cycle_id: "20260510-cluster-d-alex-native-visibility-fix"
artifact: root-cause
status: proposed
created: 2026-05-10
updated: 2026-05-10
---

# Root cause - klaster D

## Cause

Sage ma ogólny Alex-native contract, ale nie ma wystarczająco operacyjnego
miejsca, które wymusza trzy konkretne zachowania komunikacyjne:

1. **Wyjaśnienia findings dla Alexa:** instrukcje mówią, że odpowiedzi mają być
   junior-friendly, ale nie mówią, że techniczny kod błędu nie może być
   pierwszym i jedynym wyjaśnieniem.
2. **Język artefaktów workflow:** lokalny kontrakt mówi, że nowa proza `.sage`
   ma być po polsku, ale workflowy i szablony mogą być czytane zbyt literalnie
   jako angielski wzorzec treści.
3. **Widoczność postępu w Codex:** agent może prowadzić poprawny workflow Sage
   bez użycia natywnego plan/progress surface Codexa, przez co Alex widzi mniej
   niż faktyczny stan pracy.

## Evidence

- `.sage/work/20260509-alex-readable-change-explanations-fix/manifest.md`
  opisuje problem z findings typu `broken_frontmatter`, `bypass_mutation`,
  `claim_no_op` i `phase_jump_observed`, które są technicznie poprawne, ale za
  mało ludzkie jako pierwsze wyjaśnienie.
- `.sage/work/20260509-qa-workflow-polish-report-contract/manifest.md`
  pokazuje konkretną regresję: raport QA powstał po angielsku, bo agent zbyt
  literalnie potraktował angielski template.
- `.sage/work/20260509-codex-task-plan-visibility-fix/manifest.md` pokazuje
  pozytywny wzorzec: użycie `update_plan` dało widoczny pasek postępu w Codex
  UI, ale Sage nie ma jeszcze reguły kiedy to robić.
- Oficjalne OpenAI docs dla Codex App Server opisują event
  `turn/plan/updated` z krokami i statusami, a slash commands docs opisują
  `/plan` oraz elementy task progress w CLI/title. To potwierdza, że
  plan/progress jest realną powierzchnią Codexa, ale wymaga doprecyzowania
  granicy między agent instruction a client behavior.

## Chain

Brak operacyjnego kontraktu powoduje, że agent może spełnić formalne wymagania
Sage, ale nadal zostawić Alexa z raportem, który brzmi jak wewnętrzny log
systemu. To boli szczególnie przy workflowach: artefakty na dysku są poprawne,
ale rozmowa i raporty nie tłumaczą jasno, co się zmieniło, dlaczego, i gdzie
widać postęp.

Jednocześnie nadmiarowy fix też byłby problemem: powielenie tego samego wzorca
w `AGENTS.md`, generated `AGENTS.md`, constitution, navigatorze i każdym
workflowie zwiększyłoby token load oraz szum informacyjny. Poprawka musi więc
być minimalna i mieć jedno preferowane źródło prawdy dla hot-path instrukcji.

## Confidence

High dla problemu języka i prozy artefaktów. Medium dla finalnego kształtu
Visibility Fix, bo wymaga jeszcze krótkiej analizy oficjalnej powierzchni
Codex i aktualnego zachowania Desktop/CLI.
