---
cycle_id: "20260514-selfhost-sage-update-pass"
title: "Plan: selfhost sage update after Batch 6"
workflow: fix
phase: deliver
status: approved
created: 2026-05-14
updated: 2026-05-14
approval: "user authorized: jesteśmy po 6. możesz działać"
---

# Plan: selfhost sage update after Batch 6

## Goal

Zweryfikować i ewentualnie zregenerować selfhost platform files po Batchach
1-6 przez `bin/sage update`.

## Steps

1. Potwierdzić czysty baseline Git.
2. Uruchomić `bin/sage update`.
3. Sprawdzić `git status --short` oraz diff.
4. Jeśli diff jest pusty, zamknąć jako no-op update pass.
5. Jeśli diff dotyka generated surfaces, uruchomić targeted tests:
   - `stage3-agents-md.bats` dla `AGENTS.md`;
   - `stage7-skills.bats` dla `.agents/skills`;
   - config/hook tests, jeśli zmieni się `.codex` albo `.claude`.
   Jeśli generated surfaces są bez zmian, ale `sage update` dopisze managed
   `.gitignore` block dla lokalnych hook artifacts, zweryfikować `git
   check-ignore` i `git diff --check`.
6. Uruchomić `git diff --check`.
7. Raportować wynik i nie robić commit/push bez osobnego potwierdzenia.

## Stop conditions

- `bin/sage update` dotknie nieoczekiwanych plików poza scope.
- Diff wygląda jak regresja Batchy 1-6.
- Targeted verification nie przejdzie.

## Result

Update pass wykonany. Stop conditions nie wystąpiły. Tracked generated surfaces
są bez zmian; generator dopisał tylko expected managed `.gitignore` block dla
lokalnych Sage hook artifacts. Targeted verification przeszła.

## Revision After UI Finding

Alex pokazał, że Codex Desktop widzi dwa aktywne `PreToolUse` hooki. Plan
rewizji:

1. Zmienić generator Stage 5 tak, żeby `PreToolUse` miał jeden matcher group
   `Bash|apply_patch|Edit|Write` wskazujący na `pre-tool-validate.sh`.
2. Zaktualizować aktywne `.codex/hooks.json`.
3. Zaktualizować `stage5-6-hooks.bats`, żeby pilnował jednego matcher group.
4. Uruchomić `stage5-6-hooks.bats`, `stage10-tighten.bats`, `jq`, `bash -n`,
   generated diff check i `git diff --check`.

## Revision Result

Pierwsza rewizja wykonana. Generator Stage 5 i aktywny `.codex/hooks.json` używają
jednego matcher group `Bash|apply_patch|Edit|Write` dla `PreToolUse`.
`stage5-6-hooks.bats` sprawdza teraz, że długość `.hooks.PreToolUse` wynosi
`1`, więc UI nie powinno ponownie pokazać dwóch zainstalowanych hooków dla tej
samej komendy.

Verification:

- `jq '.hooks.PreToolUse | length' .codex/hooks.json` - `1`;
- `jq -e . .codex/hooks.json` - pass;
- `bash -n runtime/platforms/codex/setup/lib/hooks-deploy.sh
  runtime/platforms/codex/setup/generate-codex.sh` - pass;
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` - 13/13;
- `bin/sage update` - pass;
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats` - 14/14;
- generated surfaces diff check - pass, empty diff;
- `git diff --check` - pass.

## Revision After Thread Read

Po przeczytaniu wątku `019e25e7-de3f-7271-a2dd-7c99fbd215a3` okazało się, że
sam merge matcher groups nie wystarcza. Właściwy bug to false positive Bash
hooka: read-only `sed ... 2>/dev/null || true` został zablokowany, bo regex
traktował `2>/dev/null` jak mutujący file write.

Plan:

1. Dodać helper w `pre-tool-validate.sh`, który rozpoznaje mutujące output
   redirections, ale ignoruje deskryptorowe/no-op redirections do `/dev/null`,
   `/dev/fd/*`, `/proc/self/fd/*`, `&1`, `&2`.
2. Zastąpić szeroki regex `>` tym helperem oraz prostym token checkiem, który
   chroni tylko ścieżki repo/managed, a absolutne ścieżki poza repo przepuszcza.
3. Dla gitignored ścieżek w repo przepuszczać lokalne artefakty hooków/logów,
   ale nie managed surfaces typu `.codex/hooks.json`.
4. Dodać testy regresji dla `sed -n ... runtime/... 2>/dev/null || true`,
   outside-repo write i lokalnego gitignored hook log.
5. Uruchomić `pre-tool-validate.bats`, `stage5-6-hooks.bats`, `stage10-tighten.bats`,
   `bash -n`, `bin/sage update`, generated diff check i `git diff --check`.

## Bash Hook Revision Result

Rewizja wykonana. Bash hook nadal blokuje shell writes do managed/project paths,
ale nie blokuje już bezpiecznych deskryptorowych redirects ani outside-repo
writes.

Nowe regresje:

- `sed -n ... runtime/... 2>/dev/null || true` - allowed;
- `cat > /tmp/.../runtime/random.md` - allowed jako outside repo;
- `printf ... >> .sage/.mcp-incidents.log` - allowed jako lokalny hook/log
  artifact;
- `printf ... > .codex/hooks.json` - blocked jako managed gitignored surface.

Verification:

- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh` - pass;
- `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` - 82/82;
- `bin/sage update` - pass;
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` - 13/13;
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats` - 14/14;
- active `.codex/hooks/pre-tool-validate.sh` byte-identical to source - pass;
- `jq` check for `PreToolUse` matcher/count - `Bash|apply_patch|Edit|Write`,
  `1`;
- generated surfaces diff check - pass, empty diff;
- `git diff --check` - pass.
