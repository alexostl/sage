---
cycle_id: "20260509-runtime-process-reliability-patch"
title: "Review report: Runtime/process reliability patch"
workflow: review
phase: review
status: completed
created: 2026-05-09
updated: 2026-05-09
reviewers:
  - "openai-docs"
  - "recent-sage-threads"
  - "source-code"
verdict: "needs-revision"
---

# Review report: Runtime/process reliability patch

## Verdict

**Needs revision przed implementacją.** Kierunek patcha jest dobry, ale plan
zbyt mocno sugeruje, że hooki są pełną granicą enforcementu, a za słabo
rozpisuje instruction loading, subagents, checkpoint harness i konkretną listę
runtime/artifact strings do zmiany.

## Sources

- `manifest.md` i `plan.md` cyklu
  `20260509-runtime-process-reliability-patch`.
- Lokalne evidence z `real-use-findings.md`, `dummy-project-real-work-report.md`,
  `dummy-project-brief-test-report.md`,
  `dummy-project-artifact-docs-report.md` oraz otwartych intake manifests.
- Oficjalne OpenAI Docs:
  - [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
  - [Advanced Configuration](https://developers.openai.com/codex/config-advanced#project-instructions-discovery)
  - [Codex App Server](https://developers.openai.com/codex/app-server#api-overview)
  - [Configuration Reference](https://developers.openai.com/codex/config-reference#configtoml)

## P1 findings

### P1 — Hooki muszą być opisane jako guardrails, nie pełna granica enforcementu

Plan opiera główną ścieżkę na `PreToolUse`/`PostToolUse`, ale oficjalne docs i
lokalny kod wskazują, że trzeba myśleć defense-in-depth. `PostToolUse` jest
non-blocking i nie cofa skutków mutacji; może najwyżej logować incident i
wpływać na dalszy kontekst. `pre-tool-validate.sh` widzi claimed paths z
apply_patch command, ale nie ma pełnego semantycznego dostępu do intencji usera.

**Impact:** Patch może dać zielone hook tests, ale realny agent nadal ominie
workflow przez inną ścieżkę narzędziową albo przez behavioral failure.

**Suggested action:** Dopisać osobne zadanie defense-in-depth:
`apply_patch`, shell/Bash/unified exec, MCP/app tools, końcowy `git diff`/stan
repo po całym turnie, `PostToolUse`/`Stop` jako audit/recovery, nie jako jedyna
prewencja.

### P1 — Brakuje jawnego testu instruction loading i trust dla `.codex/`

Realny problem dotyczył ignorowania `AGENTS.md`/Developer Instructions, a plan
traktuje `developer_instructions` warunkowo. OpenAI Docs potwierdzają, że Codex
buduje instruction chain na starcie sesji, czyta `AGENTS.md` z limitem
`project_doc_max_bytes`, a project-scoped `.codex/config.toml` i hooks zależą
od trusted project.

**Impact:** Możemy poprawić treść instrukcji, ale nie sprawdzić, czy Codex ją
faktycznie ładuje w realnych sesjach.

**Suggested action:** Dodać Task 0 albo rozszerzyć Task 5 o:
instruction-chain smoke, trust-level check, limit `project_doc_max_bytes`,
restart/new-session behavior, oraz decyzję czy `developer_instructions` jest
oficjalną wspieraną warstwą dla kompaktowego contractu.

### P1 — No-spontaneous-fix nie jest deterministycznie blokowalne obecnym hookiem

`pre-tool-validate.sh` nie widzi pierwotnego promptu usera, więc nie odróżni
bug report od explicit fix mandate na poziomie samej mutacji. To może być
testowane i wzmacniane przez guidance/harness, ale nie jako twardy hook block
bez nowego intent channel.

**Impact:** Wording typu “prevent” jest zbyt mocny, jeśli implementacja ma być
guidance + harness.

**Suggested action:** Dodać realny blocker prompt `bug-report-no-fix` i rubric:
bez explicit fix mandate nie wolno mutować `src/**`, `tests/**`, `bin/sage`,
`runtime/**`. W planie pisać “detect and regress real agent behavior”, chyba że
świadomie projektujemy nowy prompt-intent hook.

## P2 findings

### P2 — Subagents/multi-agent muszą wejść do scope review/patcha

OpenAI Docs opisują subagents/multi-agent jako część customization modelu.
Plan mówi o Codex behavior, ale nie sprawdza, czy spawned subagents dziedziczą
`AGENTS.md`, `developer_instructions`, hooks i MCP availability, ani czy
reviewer/auto-review może ominąć Sage gates.

**Suggested action:** Dodać task/subtask dla subagents: inheritance, edit scope,
MCP/tool availability, reviewer behavior i manifest scope enforcement.

### P2 — `tool_search` nie powinien być frameworkowym kontraktem

Realnie w Codex Desktop mamy `tool_search`, ale oficjalne docs potwierdzają
raczej ogólną powierzchnię MCP/tool discovery: `/mcp`, app-server
`mcpServerStatus/list`, `mcpServer/tool/call`, configured MCP tools. Nazwa
`tool_search` nie powinna zostać utrwalona jako publiczny kontrakt Sage.

**Suggested action:** Zmienić wording na neutralny:
“discover MCP/Sage Memory through the available Codex tool-discovery surface;
in Codex Desktop this may be `tool_search`; in CLI/app-server verify through
available MCP status/tool surfaces.”

### P2 — Local Codex/CLI/Desktop vs Codex Cloud boundary jest niejasny

Plan opiera się na `codex exec` i local hooks, ale mówi szeroko “Codex runtime”.
Codex Cloud ma inny execution model. Bez boundary łatwo obiecać behavior,
którego cloud nie uruchamia tak samo.

**Suggested action:** Dopisać boundary: ten patch dotyczy local
Codex CLI/Desktop. Codex Cloud jest out-of-scope albo dostaje osobny smoke/audit
matrix.

### P2 — Resolver cyklu powinien być nowym API, nie zmianą `active_init_path`

Kodowo diagnoza jest trafna: `active_init_path` wybiera newest in-progress, a
`bootstrap_cycle_id` działa tylko gdy nie ma active cycle. Najbezpieczniej
dodać nową funkcję typu `resolve_cycle_for_patch "$cwd" "${claimed_paths[@]}"`
i zostawić `active_init_path` jako legacy fallback.

### P2 — Runtime localization wymaga tabeli surfaces

`bin/sage status` i `doctor` mają wiele angielskich user-facing labels, a
obecne tests asercją angielski output. Task 5 mówi “inventory”, ale nie
definiuje must-fix surfaces.

**Suggested action:** Przed kodem dodać tabelę:
`surface → expected Polish label/prose → source file → test file → must/defer`.

### P2 — Artifact language task musi wskazać realne źródła outputu

English headings typu `State`, `Context summary`, `Key decisions`,
`Next agent should`, `Spec for...` są głównie w `core/**` i
`develop/templates/**`, nie tylko w Codex setup tests.

**Suggested action:** Dopisać w planie konkretne źródła:
`core/workflows/**`, `core/capabilities/**`, `develop/templates/**`,
Codex/Claude generated mirrors i snapshot/string tests.

### P2 — Checkpoint harness i `analyze` over-escalation są pominięte

Project Dummy pokazał, że full `spec`/`plan` checkpoint behavior nadal nie jest
zweryfikowany, a `analyze` over-escalated do browser/Playwright dla lekkiej
analizy.

**Suggested action:** Checkpoint harness powinien wejść do Task 7 albo osobnego
taska. `analyze` over-escalation trzeba jawnie włączyć albo zaparkować poza tym
patchem.

### P2 — Copy-boundary regression jest scope risk

Memory fallback pasuje do runtime/process reliability. Copy-boundary regression
jest bardziej distribution hygiene bugiem.

**Suggested action:** Albo nazwać go wprost jako harness/distribution regression
w tym patchu, albo wyciągnąć do osobnego intake.

## P3 findings

### P3 — Plan jest praktycznie trzema patchami

Zakres łączy:
1. hook lifecycle + close-cycle contract,
2. no-spontaneous-fix harness/guidance,
3. localization/artifact language.

To może zostać jednym systemic cycle, ale plan powinien mieć fazy
`must ship / can defer`, żeby uniknąć partial guardrail.

### P3 — Sam artifact planu nadal częściowo łamie language contract

Po częściowej korekcie nadal trzeba przejrzeć nowy `manifest.md`, `plan.md` i
ten review report pod zasadą: artifact structure/canonical terms po angielsku,
treść prozatorska po polsku.

## Recommended plan revisions

1. Dodać Task 0: instruction loading, trust, `developer_instructions`,
   project-doc byte limit i new-session behavior.
2. Dopisać defense-in-depth model dla hooks: co blokuje `PreToolUse`, co
   audytuje `PostToolUse`/`Stop`, co sprawdza harness po całym turnie.
3. Doprecyzować close-cycle epilogue: post-mutation incident only albo
   pre-tool parser status flip.
4. Dodać subagents/multi-agent inheritance i edit-scope tests.
5. Dodać bug-report-no-fix blocker scenario do harnessu.
6. Dodać checkpoint harness; `analyze` over-escalation jawnie włączyć albo
   zaparkować.
7. Rozdzielić Task 5/6/6.5:
   runtime surfaces, generated artifact snapshots, append-language guidance.
8. Dodać surface table dla runtime localization.
9. Zneutralizować wording `tool_search` jako desktop-specific detail.
10. Dopisać boundary local Codex CLI/Desktop vs Codex Cloud.
11. Zdecydować, czy copy-boundary zostaje w tym patchu czy idzie do osobnego
    intake.

## Next checkpoint

[R] Revise — poprawić `plan.md` i `manifest.md` według review report.
[D] Discuss — omówić, co zostaje w scope, a co parkujemy.
[S] Skip — zaakceptować ryzyko i implementować obecny plan.
