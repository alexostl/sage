#!/usr/bin/env bats
# T1.6 — post-tool-check.sh: PostToolUse hook (apply_patch matcher).
#
# Plan contract (T1.6): §15.3 + §15.4.
#
# §15.3 cases:
#   - Diff matches → no incident.
#   - Diff mismatch → claim_no_op incident logged.
#   - Broken frontmatter file → broken_frontmatter incident logged.
#
# §15.4 parity (vs sage_check_post_mutation MCP tool):
#   - Check A (diff-claim) — claim_no_op + unclaimed_change incidents.
#   - Check C (frontmatter via yq) — broken_frontmatter incident.
#   - Check B (symbol existence) — absent in v1.
#
# §6.4 invariant: never blocks (exit 0 always); short-circuits on
# tool_response.metadata.exit_code ≠ 0 (apply_patch failed → no work).

setup() {
    HOOK="$BATS_TEST_DIRNAME/../post-tool-check.sh"
    [ -f "$HOOK" ] || skip "post-tool-check.sh not found at $HOOK"
    [ -x "$HOOK" ] || skip "post-tool-check.sh not executable"
    PROJECT_ROOT="$(mktemp -d -t post_tool_check_bats.XXXXXX)"
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q -b main
        git config user.email "test@test"
        git config user.name "test"
        echo "seed" > seed.txt
        git add seed.txt
        git commit -q -m "seed"
    )
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: build apply_patch DSL command.
make_patch_cmd() {
    local op="$1"
    local path="$2"
    printf '*** Begin Patch\n*** %s File: %s\n+content\n*** End Patch\n' "$op" "$path"
}

# Helper: build PostToolUse payload (PreToolUse + tool_response).
# tool_response is a STRINGIFIED JSON per §6.4.
make_payload() {
    local cmd="$1"
    local exit_code="${2:-0}"
    local cwd="${3:-$PROJECT_ROOT}"
    local cmd_json tool_response_str
    cmd_json="$(printf '%s' "$cmd" | jq -Rs .)"
    tool_response_str="$(jq -nc --argjson ec "$exit_code" \
        '{output:"ok", metadata:{exit_code:$ec, duration_seconds:0.1}}' | jq -Rs .)"
    jq -nc --arg cwd "$cwd" --argjson cmd "$cmd_json" --argjson tr "$tool_response_str" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        cwd: $cwd,
        hook_event_name: "PostToolUse",
        tool_name: "apply_patch",
        tool_input: { command: $cmd },
        tool_response: $tr
    }'
}

make_file_change_payload() {
    local kind="$1"
    local path="$2"
    local exit_code="${3:-0}"
    local cwd="${4:-$PROJECT_ROOT}"
    local tool_response_str
    tool_response_str="$(jq -nc --argjson ec "$exit_code" \
        '{output:"ok", metadata:{exit_code:$ec, duration_seconds:0.1}}' | jq -Rs .)"
    jq -nc --arg cwd "$cwd" --arg kind "$kind" --arg path "$path" --argjson tr "$tool_response_str" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        cwd: $cwd,
        hook_event_name: "PostToolUse",
        tool_name: "file_change",
        tool_input: { changes: [{kind: $kind, path: $path}] },
        tool_response: $tr
    }'
}

write_decisions() {
    local count="$1"
    mkdir -p .sage
    {
        printf '# Decisions\n\n'
        local i
        i=1
        while [ "$i" -le "$count" ]; do
            printf '### 2026-05-14 — Decision %03d\n' "$i"
            printf 'Body for decision %03d.\n\n' "$i"
            i=$((i + 1))
        done
    } > .sage/decisions.md
}

decision_entry_count() {
    grep -c '^### ' "$1" 2>/dev/null || true
}

touch_decisions_payload() {
    local cwd="${1:-$PROJECT_ROOT}"
    local cmd
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/decisions.md\n@@\n # Decisions\n*** End Patch\n')"
    make_payload "$cmd" 0 "$cwd"
}

@test "post-tool-check.sh: claimed path matches diff → no incident, exit 0" {
    cd "$PROJECT_ROOT"
    echo "modified" >> seed.txt
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: claimed but unchanged → claim_no_op incident logged" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "claim_no_op" "$log"
    grep -q "seed.txt" "$log"
}

@test "post-tool-check.sh: claimed new untracked file IS on disk → no claim_no_op (T2.1 bugfix)" {
    # Real-Codex T2.1 finding (2026-04-30): apply_patch creates a new
    # file. `git diff --name-only HEAD` misses untracked files — so the
    # M1 implementation logged a false claim_no_op even though the file
    # was correctly written. Fix: detect via `git status --porcelain`
    # which captures both modified-tracked AND untracked files.
    cd "$PROJECT_ROOT"
    mkdir -p src
    echo "world" > src/hello.txt   # simulate apply_patch having written the file
    cmd="$(make_patch_cmd Add src/hello.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: file_change-shaped payload matches diff → no claim_no_op" {
    cd "$PROJECT_ROOT"
    mkdir -p src
    echo "world" > src/from-file-change.txt
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/from-file-change.txt")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: repo with no commits, claimed file written → no false claim_no_op" {
    # Companion bug surface: in a fresh `git init` repo (no commits
    # yet), `git diff --name-only HEAD` returns empty, again triggering
    # false claim_no_op for every claimed path.
    NOCMTREE="$(mktemp -d -t no_commits.XXXXXX)"
    cd "$NOCMTREE"
    git init -q -b main
    mkdir -p src
    echo "world" > src/hello.txt
    cmd="$(make_patch_cmd Add src/hello.txt)"
    payload="$(make_payload "$cmd" 0 "$NOCMTREE")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$NOCMTREE/.sage/.mcp-incidents.log"
    found_no_op=0
    [ -f "$log" ] && grep -q "claim_no_op" "$log" && found_no_op=1
    rm -rf "$NOCMTREE"
    [ "$found_no_op" -eq 0 ]
}

@test "post-tool-check.sh: tool_response exit_code != 0 → early exit, no Check A" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd" 1)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: broken frontmatter in .sage/*.md → broken_frontmatter incident" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha
    cat > .sage/work/20260101-alpha/spec.md <<'EOF'
---
status: in-progress
title: "missing close
broken: yaml: : :
---
# spec
EOF
    git add .sage/work/20260101-alpha/spec.md
    cmd="$(make_patch_cmd Add .sage/work/20260101-alpha/spec.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "broken_frontmatter" "$log"
}

@test "post-tool-check.sh: valid frontmatter in .sage/*.md → no broken_frontmatter incident" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha
    cat > .sage/work/20260101-alpha/spec.md <<'EOF'
---
status: in-progress
title: "OK spec"
phase: design
---
# spec
EOF
    git add .sage/work/20260101-alpha/spec.md
    cmd="$(make_patch_cmd Add .sage/work/20260101-alpha/spec.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "broken_frontmatter" "$log"
    fi
}

@test "post-tool-check.sh: decisions.md is a journal, not a frontmatter artifact" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage
    cat > .sage/decisions.md <<'EOF'
# Decisions

---

### 2026-05-14 — Decision with colon

**Decision:** this journal entry is not YAML frontmatter.
EOF
    git add .sage/decisions.md
    cmd="$(make_patch_cmd Add .sage/decisions.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "broken_frontmatter" "$log"
    fi
}

@test "post-tool-check.sh: capture-only sage manifest no-op emits audit event instead of claim_no_op" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260514-capture
    cat > .sage/work/20260514-capture/manifest.md <<'EOF'
---
cycle_id: "20260514-capture"
workflow: fix
phase: intake
status: intake
---
# Capture
EOF
    git add .sage/work/20260514-capture/manifest.md
    git commit -q -m "seed capture"

    cmd="$(make_patch_cmd Update .sage/work/20260514-capture/manifest.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "capture_documentation_mutation" "$log"
    ! grep -q "claim_no_op" "$log"
}

@test "post-tool-check.sh: incident JSON line is valid (parseable + has severity)" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    line="$(tail -n1 "$log")"
    echo "$line" | jq -e '.kind' >/dev/null
    echo "$line" | jq -e '.severity' >/dev/null
    echo "$line" | jq -e '.ts' >/dev/null
}

@test "post-tool-check.sh: invalid JSON payload → exit 0 (never blocks per §6.4)" {
    cd "$PROJECT_ROOT"
    run bash -c "echo 'not-json' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "post-tool-check.sh: empty patch (no claimed paths) → exit 0, no incidents" {
    cd "$PROJECT_ROOT"
    cmd="*** Begin Patch\n*** End Patch\n"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "post-tool-check.sh: completing manifest plus implementation file logs post_completion_mutation" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha src
    cat > .sage/work/20260101-alpha/manifest.md <<'EOF'
---
cycle_id: "20260101-alpha"
status: completed
---
EOF
    echo "changed" > src/late.sh
    git add .sage/work/20260101-alpha/manifest.md src/late.sh
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n+status: completed\n*** Add File: src/late.sh\n+changed\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "post_completion_mutation" "$log"
    grep -q "src/late.sh" "$log"
}

@test "post-tool-check.sh: explicit closeout_epilogue marker suppresses post_completion_mutation" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha src
    cat > .sage/work/20260101-alpha/manifest.md <<'EOF'
---
cycle_id: "20260101-alpha"
status: completed
closeout_epilogue: allowed
---
EOF
    echo "changed" > src/late.sh
    git add .sage/work/20260101-alpha/manifest.md src/late.sh
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n+status: completed\n*** Add File: src/late.sh\n+changed\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "post_completion_mutation" "$log"
    fi
}

@test "post-tool-check.sh: absolute apply_patch path matches relative porcelain → no false claim_no_op" {
    # T2.7 follow-up (2026-04-30): Codex emits absolute paths in apply_patch
    # DSL. Pre-fix, claimed_paths was absolute and porcelain was relative →
    # contains() never matched → false claim_no_op + false unclaimed_change
    # for the SAME file. Real harness baseline showed this on AGENTS.md.
    cd "$PROJECT_ROOT"
    echo "modified" >> seed.txt
    abs_path="$PROJECT_ROOT/seed.txt"
    cmd="$(make_patch_cmd Update "$abs_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
        ! grep -q "unclaimed_change" "$log"
    fi
}

@test "post-tool-check.sh: macOS /private prefix in claim → no false claim_no_op against relative porcelain" {
    cd "$PROJECT_ROOT"
    case "$PROJECT_ROOT" in
        /private/*) skip "PROJECT_ROOT already canonical with /private" ;;
    esac
    echo "modified" >> seed.txt
    abs_path="/private${PROJECT_ROOT}/seed.txt"
    cmd="$(make_patch_cmd Update "$abs_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: hook bookkeeping logs in .sage/ are excluded from unclaimed_change" {
    # Real-Codex T2.1a finding (2026-04-30): pre-tool-validate.sh appends to
    # .sage/.session-mutations.log BEFORE apply_patch runs. PostToolUse then
    # sees that file as modified-but-not-claimed → false unclaimed_change
    # incident on every successful mutation. Fix: exclude .sage/.*.log paths
    # from the diff-claim comparison since they are hook-generated, not
    # agent-written.
    cd "$PROJECT_ROOT"
    # Simulate the hook bookkeeping side-effect.
    mkdir -p .sage
    printf '{"session":"prior"}\n' > .sage/.session-mutations.log
    printf '{"prev":"warn"}\n' > .sage/.mcp-incidents.log
    git add .
    git commit -q -m "with bookkeeping baseline"
    # Now agent mutates a single file in scope.
    echo "modified" >> seed.txt
    # And pre-tool-validate appended a new line to .session-mutations.log
    # (simulating its own behaviour during this turn).
    printf '{"session":"now"}\n' >> .sage/.session-mutations.log
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    # The bookkeeping file should NOT appear as unclaimed_change.
    found_unclaimed_log=0
    [ -f "$log" ] && grep -q '"file":".sage/.session-mutations.log"' "$log" && found_unclaimed_log=1
    [ "$found_unclaimed_log" -eq 0 ]
}

@test "post-tool-check.sh: exactly 50 decisions does not rotate archive" {
    cd "$PROJECT_ROOT"
    write_decisions 50
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(decision_entry_count "$PROJECT_ROOT/.sage/decisions.md")" -eq 50 ]
    [ ! -f "$PROJECT_ROOT/.sage/decisions-archive.md" ]
}

@test "post-tool-check.sh: 51 decisions rotates one oldest entry to archive" {
    cd "$PROJECT_ROOT"
    write_decisions 51
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(decision_entry_count "$PROJECT_ROOT/.sage/decisions.md")" -eq 50 ]
    [ -f "$PROJECT_ROOT/.sage/decisions-archive.md" ]
    [ "$(decision_entry_count "$PROJECT_ROOT/.sage/decisions-archive.md")" -eq 1 ]
    grep -q 'Decision 051' "$PROJECT_ROOT/.sage/decisions-archive.md"
    ! grep -q 'Decision 051' "$PROJECT_ROOT/.sage/decisions.md"
}

@test "post-tool-check.sh: archive rotation preserves headers and prepends overflow newest-first" {
    cd "$PROJECT_ROOT"
    write_decisions 52
    cat > .sage/decisions-archive.md <<'EOF'
# Decisions Archive

### 2026-05-01 — Existing archived decision
Old archive body.
EOF
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    head -n1 "$PROJECT_ROOT/.sage/decisions.md" | grep -q '^# Decisions$'
    head -n1 "$PROJECT_ROOT/.sage/decisions-archive.md" | grep -q '^# Decisions Archive$'
    first_archive_heading="$(grep '^### ' "$PROJECT_ROOT/.sage/decisions-archive.md" | sed -n '1p')"
    second_archive_heading="$(grep '^### ' "$PROJECT_ROOT/.sage/decisions-archive.md" | sed -n '2p')"
    third_archive_heading="$(grep '^### ' "$PROJECT_ROOT/.sage/decisions-archive.md" | sed -n '3p')"
    [ "$first_archive_heading" = "### 2026-05-14 — Decision 051" ]
    [ "$second_archive_heading" = "### 2026-05-14 — Decision 052" ]
    [ "$third_archive_heading" = "### 2026-05-01 — Existing archived decision" ]
}

@test "post-tool-check.sh: linked worktree does not rotate decisions archive" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage
    printf '# Decisions\n\n' > .sage/decisions.md
    git add .sage/decisions.md
    git commit -q -m "seed decisions"
    WORKTREE_ROOT="$(mktemp -d -t post_tool_worktree.XXXXXX)"
    rm -rf "$WORKTREE_ROOT"
    git worktree add -q "$WORKTREE_ROOT"
    (
        cd "$WORKTREE_ROOT" || exit 1
        write_decisions 51
    )
    payload="$(touch_decisions_payload "$WORKTREE_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(decision_entry_count "$WORKTREE_ROOT/.sage/decisions.md")" -eq 51 ]
    [ ! -f "$WORKTREE_ROOT/.sage/decisions-archive.md" ]
    git worktree remove -f "$WORKTREE_ROOT" >/dev/null 2>&1 || true
}

@test "post-tool-check.sh: failed apply_patch response does not rotate decisions" {
    cd "$PROJECT_ROOT"
    write_decisions 51
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/decisions.md\n@@\n # Decisions\n*** End Patch\n')"
    payload="$(make_payload "$cmd" 1)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(decision_entry_count "$PROJECT_ROOT/.sage/decisions.md")" -eq 51 ]
    [ ! -f "$PROJECT_ROOT/.sage/decisions-archive.md" ]
}

@test "post-tool-check.sh: malformed decisions file fails open without data loss" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage
    cat > .sage/decisions.md <<'EOF'
This file has no decisions header.

### 2026-05-14 — Decision 001
Body.
EOF
    before="$(cksum < .sage/decisions.md)"
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    after="$(cksum < .sage/decisions.md)"
    [ "$before" = "$after" ]
    [ ! -f "$PROJECT_ROOT/.sage/decisions-archive.md" ]
}

@test "post-tool-check.sh: archive rotation is idempotent" {
    cd "$PROJECT_ROOT"
    write_decisions 51
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    first_current="$(cksum < .sage/decisions.md)"
    first_archive="$(cksum < .sage/decisions-archive.md)"
    payload="$(touch_decisions_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$first_current" = "$(cksum < .sage/decisions.md)" ]
    [ "$first_archive" = "$(cksum < .sage/decisions-archive.md)" ]
}
