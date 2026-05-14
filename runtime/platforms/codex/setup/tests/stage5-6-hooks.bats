#!/usr/bin/env bats
# T1.13 — Stage 5 (hooks.json) + Stage 6 (deploy hook scripts).
#
# Plan contract (T1.13):
#   Stage 5: full regenerate of `<target>/.codex/hooks.json` registry —
#     4 events (SessionStart, PreToolUse[apply_patch|Edit|Write + Bash],
#     PostToolUse[apply_patch|Edit|Write], Stop). Backup user file
#     before overwrite when content differs.
#   Stage 6: copy `<sage>/runtime/platforms/codex/hooks/*.sh` →
#     `<target>/.codex/hooks/*.sh` with mode 0755 + lib/ subdir.
#     Full regenerate, no backup (Sage runtime code).
#
# v1 spec ref: §4 Stage 5 + Stage 6.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage56_hooks.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage() {
    local stage="$1"
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset base --stage "$stage"
}

# ─── Stage 5 ────────────────────────────────────────────────────────

@test "stage5: creates .codex/hooks.json" {
    run run_stage 5
    [ "$status" -eq 0 ]
    [ -s "$TARGET/.codex/hooks.json" ]
}

@test "stage5: hooks.json parses as valid JSON" {
    run_stage 5
    jq -e . "$TARGET/.codex/hooks.json" >/dev/null
}

@test "stage5: SessionStart → session-init.sh" {
    run_stage 5
    cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$TARGET/.codex/hooks.json")"
    [ "$cmd" = ".codex/hooks/session-init.sh" ]
}

@test "stage5: PreToolUse uses file-edit matcher aliases → pre-tool-validate.sh" {
    run_stage 5
    matcher="$(jq -r '.hooks.PreToolUse[0].matcher' "$TARGET/.codex/hooks.json")"
    cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$TARGET/.codex/hooks.json")"
    [ "$matcher" = "apply_patch|Edit|Write" ]
    [ "$cmd" = ".codex/hooks/pre-tool-validate.sh" ]
}

@test "stage5: PreToolUse uses matcher=Bash → pre-tool-validate.sh" {
    run_stage 5
    matcher="$(jq -r '.hooks.PreToolUse[1].matcher' "$TARGET/.codex/hooks.json")"
    cmd="$(jq -r '.hooks.PreToolUse[1].hooks[0].command' "$TARGET/.codex/hooks.json")"
    [ "$matcher" = "Bash" ]
    [ "$cmd" = ".codex/hooks/pre-tool-validate.sh" ]
}

@test "stage5: PostToolUse uses file-edit matcher aliases → post-tool-check.sh" {
    run_stage 5
    matcher="$(jq -r '.hooks.PostToolUse[0].matcher' "$TARGET/.codex/hooks.json")"
    cmd="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$TARGET/.codex/hooks.json")"
    [ "$matcher" = "apply_patch|Edit|Write" ]
    [ "$cmd" = ".codex/hooks/post-tool-check.sh" ]
}

@test "stage5: Stop → turn-audit.sh" {
    run_stage 5
    cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$TARGET/.codex/hooks.json")"
    [ "$cmd" = ".codex/hooks/turn-audit.sh" ]
}

@test "stage5: re-run with user-edited file → backup written" {
    mkdir -p "$TARGET/.codex"
    echo '{"hooks": {"UserCustom": []}}' > "$TARGET/.codex/hooks.json"
    run run_stage 5
    [ "$status" -eq 0 ]
    ls "$TARGET/.codex"/hooks.json.user-edit-backup-* >/dev/null 2>&1
}

# ─── Stage 6 ────────────────────────────────────────────────────────

@test "stage6: deploys all 4 hook scripts to .codex/hooks/" {
    run run_stage 6
    [ "$status" -eq 0 ]
    [ -f "$TARGET/.codex/hooks/session-init.sh" ]
    [ -f "$TARGET/.codex/hooks/pre-tool-validate.sh" ]
    [ -f "$TARGET/.codex/hooks/post-tool-check.sh" ]
    [ -f "$TARGET/.codex/hooks/turn-audit.sh" ]
}

@test "stage6: all 4 hook scripts are executable" {
    run_stage 6
    for h in session-init pre-tool-validate post-tool-check turn-audit; do
        [ -x "$TARGET/.codex/hooks/$h.sh" ] || {
            echo "NOT EXECUTABLE: $h.sh"
            return 1
        }
    done
}

@test "stage6: deploys lib/ subdir helpers" {
    run_stage 6
    [ -f "$TARGET/.codex/hooks/lib/json_log.sh" ]
    [ -f "$TARGET/.codex/hooks/lib/active_init.sh" ]
    [ -f "$TARGET/.codex/hooks/lib/path_normalize.sh" ]
    [ -f "$TARGET/.codex/hooks/lib/dirty_state.sh" ]
}

@test "stage6: deployed scripts are byte-identical to source" {
    run_stage 6
    for h in session-init pre-tool-validate post-tool-check turn-audit; do
        cmp -s "$REPO_ROOT/runtime/platforms/codex/hooks/$h.sh" \
               "$TARGET/.codex/hooks/$h.sh" || {
            echo "MISMATCH: $h.sh"
            return 1
        }
    done
}

@test "stage6: re-run overwrites without backup (Sage runtime, full regenerate)" {
    run_stage 6
    # Modify deployed file.
    echo "# user tampered" >> "$TARGET/.codex/hooks/session-init.sh"
    run_stage 6
    # Overwritten — tampering gone.
    ! grep -q '# user tampered' "$TARGET/.codex/hooks/session-init.sh"
    # No backup file.
    ! ls "$TARGET/.codex/hooks"/*.user-edit-backup-* >/dev/null 2>&1
}

@test "stage6: fails when SAGE_FRAMEWORK invalid" {
    run env SAGE_FRAMEWORK=/nonexistent "$GEN" \
        --target "$TARGET" --preset base --stage 6
    [ "$status" -ne 0 ]
}
