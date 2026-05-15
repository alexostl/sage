#!/usr/bin/env bats
# T1.16 — Stage 10: tighten sanity sweep + emit summary table.
#
# Plan contract (T1.16):
#   - Every check in spec §4 Stage 10 runs in implementation.
#   - B2 tightening: when source preset has gate scripts, target MUST
#     have them too (count match). Empty src dir → info message, ok.
#   - B1 + B3 already wired in T1.10; this task confirms they hold
#     under tightened conditions.
#   - PASSED branch emits a summary table covering what's deployed.
#   - FAILED branch keeps "what failed, what to do" + exit 2.
#
# v1 spec ref: §4 Stage 10, §15.2 sanity bullets.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage10_tighten.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

# Build a faked-complete target by running the relevant stages end-to-end.
build_complete_target() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 3 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 4 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 5 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 6 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 7 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 9 >/dev/null
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 9a >/dev/null
}

run_stage_10() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 10
}

# ─── Tightening: B2 gates count must match ───────────────────────────

@test "stage10: passes on a fully generated target (3→9a then 10)" {
    build_complete_target
    run run_stage_10
    [ "$status" -eq 0 ]
}

@test "stage10: fails when gates scripts dir is missing (src has scripts)" {
    build_complete_target
    rm -rf "$TARGET/.sage/gates/scripts"
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'gates'
}

@test "stage10: fails when gates scripts dir is empty (src has scripts)" {
    build_complete_target
    # Empty target gates dir vs non-empty src.
    rm -f "$TARGET/.sage/gates/scripts"/*.sh
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'gates'
}

@test "stage10: fails when gates scripts count mismatches source" {
    build_complete_target
    # Remove one to force a count mismatch.
    local victim
    victim="$(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh' | head -1)"
    [ -n "$victim" ]
    rm -f "$victim"
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'gates.*count\|count.*gates'
}

@test "stage10: empty source preset → info message, ok" {
    # Stage 9a with empty fw → emits info, exits 0. Stage 10 with the
    # same fw + the rest of the target faked → must pass when there
    # genuinely are no gates to compare against.
    local fake_fw
    fake_fw="$(mktemp -d -t stage10_emptyfw.XXXXXX)"
    mkdir -p \
        "$fake_fw/core/gates/scripts" \
        "$fake_fw/core/workflows" \
        "$fake_fw/core/capabilities"
    # Build target against the real fw, then point Stage 10 at the empty fw.
    build_complete_target
    rm -rf "$TARGET/.sage/gates/scripts"
    run env SAGE_FRAMEWORK="$fake_fw" "$GEN" --target "$TARGET" --preset base --stage 10
    [ "$status" -eq 0 ]
    rm -rf "$fake_fw"
}

# ─── Summary table in PASSED branch ──────────────────────────────────

@test "stage10: PASSED output includes a summary section" {
    build_complete_target
    run run_stage_10
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'summary\|deployed'
}

@test "stage10: summary mentions AGENTS.md" {
    build_complete_target
    run run_stage_10
    echo "$output" | grep -q 'AGENTS.md'
}

@test "stage10: summary mentions hooks (count or names)" {
    build_complete_target
    run run_stage_10
    echo "$output" | grep -qi 'hook'
}

@test "stage10: fails when deployed hook script drifts from source" {
    build_complete_target
    echo "# drift" >> "$TARGET/.codex/hooks/pre-tool-validate.sh"
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'hook drift'
}

@test "stage10: fails when deployed hook lib drifts from source" {
    build_complete_target
    echo "# drift" >> "$TARGET/.codex/hooks/lib/json_log.sh"
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'hook lib drift'
}

@test "stage10: summary reports hooks=true and not codex_hooks=true" {
    build_complete_target
    run run_stage_10
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'hooks=true'
    ! echo "$output" | grep -q 'codex_hooks=true'
}

@test "stage10: summary mentions skills loaders" {
    build_complete_target
    run run_stage_10
    echo "$output" | grep -qi 'skill'
}

@test "stage10: summary mentions gates" {
    build_complete_target
    run run_stage_10
    echo "$output" | grep -qi 'gate'
}

@test "stage10: summary mentions constitution preset" {
    build_complete_target
    run run_stage_10
    echo "$output" | grep -qi 'preset\|constitution'
}

# ─── B1 + B3 still hold under tightened sanity ───────────────────────

@test "stage10: B1 still enforced — missing Sage Memory discovery/fallback wording → fail" {
    build_complete_target
    # Strip the required Rule 1A phrases from AGENTS.md to simulate broken render.
    perl -i -pe 's/Discover available Sage Memory tools//g; s/Fall back to `\.sage-memory\/` files only when MCP tools are unavailable//g' "$TARGET/AGENTS.md"
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'Sage Memory\|Rule 1A'
}

@test "stage10: B3 still enforced — missing extends: in constitution → fail" {
    build_complete_target
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
# no frontmatter at all
EOF
    run run_stage_10
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'extends\|constitution'
}
