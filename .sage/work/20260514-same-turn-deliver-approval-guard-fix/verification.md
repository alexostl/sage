---
status: completed
created: 2026-05-14
updated: 2026-05-14
---

# Verification

## Commands

```text
bats --filter 'same-turn|prior approved|semantic_reclassification checkpoint|milestone plan|conditional revision|marker without|manifest-only prior|prior-turn plan' runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
```

```text
1..10
ok 1 pre-tool-validate.sh: same-turn manifest cannot authorize source file_change
ok 2 pre-tool-validate.sh: same-turn plan still cannot authorize source file_change
ok 3 pre-tool-validate.sh: prior-turn plan can authorize source file_change
ok 4 pre-tool-validate.sh: prior approved plan allows same-turn manifest bookkeeping before source edit
ok 5 pre-tool-validate.sh: semantic_reclassification checkpoint after approval does not renew same-turn block
ok 6 pre-tool-validate.sh: same-turn milestone plan bookkeeping does not count as canonical self-approval
ok 7 pre-tool-validate.sh: conditional revision marker allows same-turn canonical plan revision
ok 8 pre-tool-validate.sh: marker without prior canonical plan evidence still blocks AGENTS.md
ok 9 pre-tool-validate.sh: manifest-only prior evidence without canonical plan still blocks AGENTS.md
ok 10 pre-tool-validate.sh: same-turn manifest cannot authorize AGENTS.md
```

```text
bats --filter 'post-plan implementation mode choice' runtime/platforms/codex/setup/tests/stage3-agents-md.bats
```

```text
1..1
ok 1 stage3: generated AGENTS.md preserves post-plan implementation mode choice
```

```text
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/setup/lib/agents-md.sh runtime/platforms/codex/setup/generate-codex.sh
```

```text
pass
```

```text
git diff --check
```

```text
pass
```

```text
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
```

```text
1..93
ok 1 pre-tool-validate.sh: no active cycle → exit 2, stderr says no active cycle
ok 2 pre-tool-validate.sh: Bash read command is allowed without active cycle
ok 3 pre-tool-validate.sh: Bash read command with stderr to /dev/null is allowed
ok 4 pre-tool-validate.sh: Bash shell edit to manifest active_session_id is blocked
ok 5 pre-tool-validate.sh: Bash write to project path is blocked
ok 6 pre-tool-validate.sh: Bash write outside repo is allowed even with guarded-looking path segments
ok 7 pre-tool-validate.sh: Bash write to local ignored hook log is allowed
ok 8 pre-tool-validate.sh: Bash write to managed gitignored hooks json is blocked
ok 9 pre-tool-validate.sh: active cycle, path in scope → exit 0 + mutations log appended
ok 10 pre-tool-validate.sh: active cycle, inline scope.writable exact path → exit 0
...
ok 93 pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue
```

```text
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
```

```text
1..52
ok 1 stage3: creates AGENTS.md at target
ok 2 stage3: AGENTS.md has 'Sage — Project Instructions' header
...
ok 52 stage3: generated AGENTS.md supports cross-cycle capture-only routing
```

## Result

Targeted regressions and full affected suites passed.
