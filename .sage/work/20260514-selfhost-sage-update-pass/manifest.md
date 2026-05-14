---
cycle_id: "20260514-selfhost-sage-update-pass"
title: "Fix: selfhost sage update after Batch 6"
workflow: fix
phase: completion-checkpoint
status: completed
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P2
classification: Moderate
semantic_reclassification: accepted
source: "user requested post-Batch-6 sage update"
scope:
  - ".sage/work/20260514-selfhost-sage-update-pass/*"
  - ".sage/decisions.md"
  - "AGENTS.md"
  - "CLAUDE.md"
  - ".agents/**"
  - ".claude/**"
  - ".codex/**"
  - ".gitignore"
  - ".sage/work/**/plan.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
---

# Fix: selfhost sage update after Batch 6

## State

**Current phase:** completion-checkpoint - Bash hook false positive został
naprawiony i zweryfikowany.

**Next step:** Alex może odświeżyć Hooks UI i sprawdzić zachowanie na zwykłym
read-only shell command z `2>/dev/null`. Nie wykonano stage/commit/push.

## Verification

`bin/sage update` zakończył się `exit 0` i zregenerował Claude Code oraz Codex
platform files.

Diff po update:

- tracked generated surfaces bez zmian:
  `AGENTS.md`, `CLAUDE.md`, `.agents`, `.claude`, `.codex/config.toml`,
  `.codex/hooks`, `.codex/hooks.json`;
- jedyna zmiana generatora w tracked files to managed `.gitignore` block dla
  lokalnych Sage hook artifacts;
- generator utworzył ignored backup `.codex/hooks.json.user-edit-backup-*`.

Checks:

- `git diff --check` - pass;
- tracked generated diff check - pass, 0 bytes diff;
- `git check-ignore -v` dla `.sage/.mcp-incidents.log`,
  `.sage/.session-mutations.log`, `.sage/.skipped-checks.log`,
  `.sage/.approval-pending`, `.sage/.codex-validated-version` - pass;
- `bash -n bin/sage runtime/platforms/codex/setup/generate-codex.sh
  runtime/platforms/claude-code/setup/generate-claude-code.sh` - pass;
- `bats runtime/platforms/codex/setup/tests/stage9-bootstrap.bats` - 18/18;
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` - 51/51;
- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats` - 12/12.

## Revision: duplicated PreToolUse UI entry

Codex Desktop pokazał dwa aktywne hooki pod `PreToolUse`, bo generated
`.codex/hooks.json` miał dwa matcher groups uruchamiające tę samą komendę
`.codex/hooks/pre-tool-validate.sh`:

- `apply_patch|Edit|Write`;
- `Bash`.

To nie oznaczało podwójnego wykonania dla tego samego tool call, ale UI i
operacyjny model pokazywały dwa hooki. Oficjalny Codex hooks contract mówi, że
`matcher` jest regexem, więc te ścieżki można połączyć w jeden matcher group:
`Bash|apply_patch|Edit|Write`.

## Revision Result

Wdrożono pierwszą część poprawki w generatorze Stage 5:

- `runtime/platforms/codex/setup/lib/hooks-deploy.sh` generuje jeden
  `PreToolUse` matcher group: `Bash|apply_patch|Edit|Write`;
- aktywny `.codex/hooks.json` po `bin/sage update` ma
  `.hooks.PreToolUse | length == 1`;
- `runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` pilnuje, że Stage
  5 generuje jeden matcher group dla `Bash`, `apply_patch`, `Edit`, `Write`.

Po przeczytaniu wątku z Codex Desktop doprecyzowano jednak, że to nie zamyka
całego problemu. Jeden matcher group naprawia UI, ale nie naprawia samej
nerwowości Bash hooka.

## Revision: Bash hook false positive

Wątek `019e25e7-de3f-7271-a2dd-7c99fbd215a3` pokazuje realny false positive:
read-only command
`sed -n '1,160p' .../runtime/platforms/codex/hooks/hooks.json 2>/dev/null || true`
została zablokowana jako mutujący Bash command.

Root cause: `pre-tool-validate.sh` traktował prawie każdy `>` jako mutację.
`2>/dev/null` jest tylko wyciszeniem stderr, ale regex ustawiał
`mutating=1`; ponieważ ta sama komenda zawierała ścieżkę `runtime/...`,
ustawiał też `targets_guarded=1` i blokował bezpieczny odczyt.

Plan rewizji:

1. Rozdzielić wykrywanie mutujących komend (`cat >`, `tee`, `sed -i`,
   `perl -pi`, `touch`, `mkdir`, `rm`, `mv`, `cp`, `install`) od wykrywania
   output redirections.
2. Dla redirections ignorować nie-mutujące targety deskryptorów, szczególnie
   `/dev/null`, `/dev/fd/*`, `/proc/self/fd/*`, `&1`, `&2`.
3. Uznawać mutacje poza repo za legalne dla Bash guard, nawet jeśli absolutna
   ścieżka poza repo zawiera segment typu `runtime/` albo `src/`.
4. Dla gitignored ścieżek w repo zachować prosty podział: lokalne artefakty
   hooków/logów przechodzą, managed surfaces typu `.codex/hooks.json` nadal są
   chronione przed Bash writes.
5. Dodać regresje dla `sed -n ... runtime/... 2>/dev/null || true`, outside-repo
   write i lokalnego gitignored hook log.
6. Zachować istniejące blokady dla Bash writes do project/managed paths.

## Bash Hook Revision Result

Wdrożono minimalną heurystykę Bash guard:

- `2>/dev/null`, `>/dev/null`, `/dev/fd/*`, `/proc/self/fd/*`, `&1`, `&2` nie
  są traktowane jako mutujące file writes;
- absolutne ścieżki poza target repo są legalne dla Bash guard, nawet jeśli
  zawierają segmenty typu `runtime/` albo `src/`;
- lokalne ignored hook/log artifacts, np. `.sage/.mcp-incidents.log`, są
  dozwolone;
- managed/generated surfaces w repo, np. `.codex/hooks.json`, nadal są
  blokowane przy Bash write i powinny iść przez legalną ścieżkę generatora albo
  `apply_patch`.

Verification po Bash hook rewizji:

- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh` - pass;
- `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` - 82/82;
- `bin/sage update` - pass, Stage 10 sanity sweep `PASSED`;
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` - 13/13;
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats` - 14/14;
- active hook byte-identical to source - pass;
- `jq` check for `PreToolUse` matcher/count - `Bash|apply_patch|Edit|Write`,
  `1`;
- generated surfaces diff check - pass, empty diff;
- `git diff --check` - pass.

Verification po rewizji:

- `jq '.hooks.PreToolUse | length' .codex/hooks.json` - `1`;
- `jq -e . .codex/hooks.json` - pass;
- `bash -n runtime/platforms/codex/setup/lib/hooks-deploy.sh
  runtime/platforms/codex/setup/generate-codex.sh` - pass;
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` - 13/13;
- `bin/sage update` - pass, Stage 10 sanity sweep `PASSED`;
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats` - 14/14;
- generated surfaces diff check dla `AGENTS.md`, `CLAUDE.md`, `.agents`,
  `.claude`, `.codex/config.toml`, `.codex/hooks` - pass, empty diff;
- `git diff --check` - pass.

## Problem

Batche 1-6 zmieniały generated guidance, hooki, skill loadery, prompt policy i
Codex/Claude instruction surfaces. Selfhost repo powinno po takim pakiecie
sprawdzić, czy `bin/sage update` nadal generuje spójne pliki platformowe i czy
nie ma driftu między źródłem frameworka a zainstalowanymi surface files.

## Scope boundary

To jest update/regeneration audit, nie nowy feature. Nie zmieniamy runtime
logiki ręcznie. Jeśli `bin/sage update` wygeneruje duży lub nieoczekiwany diff,
zatrzymujemy się po diagnozie zamiast ręcznie dopisywać poprawki poza tym
cyklem.
