---
cycle_id: "20260509-blocking-hook-guidance-review"
title: "Review: guidance jakości komunikatów blokujących hooków"
workflow: review
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: true
priority: P1
folded_into: "20260510-mutation-intent-preflight-gap"
source: "conversation"
suggested_workflow: review
related:
  - ".codex/hooks/pre-tool-validate.sh"
  - ".codex/hooks/post-tool-check.sh"
  - ".codex/hooks/turn-audit.sh"
  - ".codex/hooks/session-init.sh"
  - ".codex/hooks/lib/bootstrap_check.sh"
  - ".codex/hooks/lib/recovery_autofix.sh"
  - ".sage/work/20260509-hook-routing-command-audit/manifest.md"
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-sage-methodology-activation-review/manifest.md"
---

# Review: guidance jakości komunikatów blokujących hooków

## State

**Current phase:** completed - finding skonsumowany przez anchor cycle
`20260510-mutation-intent-preflight-gap`.

**Next step:** Brak osobnej review implementacji w tym cyklu; patrz anchor
cycle i jego `verification.md`.

## Finding

Podczas próby dopisania `review-report.md` do cyklu
`20260509-sage-methodology-activation-review`, hook PreToolUse zablokował zapis
i podał ogólny komunikat:

```text
Next legal move: run `sage status`, then explicitly `sage continue` the right
cycle or start a new workflow.
```

Ten komunikat był częściowo trafny, bo problemem był brak aktywnego cyklu.
Ale nie doprowadził agenta do najlepszej ścieżki:

- `bin/sage continue` nie istnieje jako CLI subcommand;
- komunikat nie powiedział jasno, że dla wskazanego intake cycle trzeba najpierw
  wykonać formalny resume przez zmianę `manifest.md`;
- komunikat nie rozróżniał CLI, skill/slash workflow i natural-language action;
- agent pozostał zablokowany mimo jawnej zgody użytkownika na kontynuację
  konkretnego cyklu.

Alex wskazał szerszy wymóg: hook blokujący powinien równocześnie blokować i
nawigować. Poza "nie wolno" powinien mówić:

- co jest obecnym stanem;
- czego brakuje;
- jaki artefakt/status/phase trzeba zmienić;
- jaka dokładnie jest następna legalna akcja;
- czy mowa o komendzie CLI, skillu Codexa, slash command, czy instrukcji dla
  agenta.

## Candidate review scope

Review powinno objąć co najmniej:

- `pre-tool-validate.sh` - wszystkie `BLOCKING` i `no active cycle` messages;
- `post-tool-check.sh` - blokady/audyt po mutacji;
- `turn-audit.sh` - finalne blokady turnu;
- `session-init.sh` - guidance przy starcie sesji;
- helpery `bootstrap_check.sh`, `recovery_autofix.sh`, `artifact_order.sh`,
  `active_init.sh`;
- generated hook copies w `runtime/platforms/codex/**`, jeśli różnią się od
  zainstalowanych `.codex/hooks/**`;
- analogiczne Claude Code hook/status guidance, jeśli istnieje.

## Review questions

1. Czy każdy blocking path zawiera wykonalny next legal move?
2. Czy komunikat rozróżnia realne CLI komendy od Codex skill/slash workflow?
3. Czy komunikat mówi agentowi, który artefakt albo frontmatter ma zmienić?
4. Czy komunikat unika sugerowania obejść typu tymczasowe rozszerzenie scope
   niezwiązanego cyklu?
5. Czy da się napisać test/harness, który waliduje jakość tych komunikatów?

## Desired output

Review powinno wyprodukować raport z tabelą:

- hook path;
- warunek blokady;
- obecny komunikat;
- czy next legal move jest wykonalny;
- brakująca guidance;
- rekomendowany fix owner/cycle.

## Boundary

Ten cykl jest review-only. Nie zmienia hooków. Jeśli review potwierdzi braki,
implementacja powinna trafić do `/sage:fix`, prawdopodobnie przez
`20260509-hook-routing-command-audit` albo osobny, węższy fix.
