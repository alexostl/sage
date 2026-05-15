#!/usr/bin/env bats

setup() {
    RUN_HARNESS="$BATS_TEST_DIRNAME/../run-harness.sh"
    [ -x "$RUN_HARNESS" ] || skip "run-harness.sh not executable"
    TMPDIR_HARNESS="$(mktemp -d -t run_harness_bats.XXXXXX)"
}

teardown() {
    rm -rf "$TMPDIR_HARNESS"
}

@test "run-harness.sh: parses markdown auto-fix log headings as safe_auto_fix" {
    log="$TMPDIR_HARNESS/.auto-fixes.log"
    cat > "$log" <<'EOF'
## 2026-05-10T12:00:00Z — same-cycle documentation scope update

- Severity: low
- Why safe: same-cycle documentation only
EOF

    run env HARNESS_TEST_READ_LOG=1 "$RUN_HARNESS" "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "low"' >/dev/null
}

@test "run-harness.sh: uses CLI hook compatibility flags for real harness runs" {
    grep -q -- '--enable codex_hooks' "$RUN_HARNESS"
    grep -q -- 'trust_level=\\"trusted\\"' "$RUN_HARNESS"
    ! grep -q -- '--ignore-user-config' "$RUN_HARNESS"
}

@test "run-harness.sh: supports targeted scenario and hook-mode discovery runs" {
    grep -q -- 'HARNESS_SCENARIOS' "$RUN_HARNESS"
    grep -q -- 'HARNESS_HOOK_MODE' "$RUN_HARNESS"
    grep -q -- 'HARNESS_SERVICE_TIER' "$RUN_HARNESS"
    grep -q -- 'HARNESS_CODEX_HOME' "$RUN_HARNESS"
    grep -q -- 'SECONDARY_TARGET' "$RUN_HARNESS"
    grep -q -- '__HARNESS_SECONDARY_TARGET__' "$RUN_HARNESS"
    grep -q -- 'CODEX_HOME="$HARNESS_CODEX_HOME"' "$RUN_HARNESS"
    grep -q -- 'HARNESS_RUN_MODE="targeted"' "$RUN_HARNESS"
    grep -q -- 'run_mode:$run_mode' "$RUN_HARNESS"
    ! grep -q -- 'service_tier="fast"' "$RUN_HARNESS"
}

@test "run-harness.sh: selects prompts by scenario id, basename, or filename" {
    run env HARNESS_LIST_PROMPTS_ONLY=1 HARNESS_SCENARIOS="08-safe-autofix-metadata,13-mutation-preflight-lightweight" "$RUN_HARNESS"
    [ "$status" -eq 0 ]
    [ "$output" = $'08-safe-autofix-metadata\n13-mutation-preflight-lightweight' ]

    run env HARNESS_LIST_PROMPTS_ONLY=1 HARNESS_SCENARIOS="08-safe-autofix-metadata.txt 13-mutation-preflight-lightweight" "$RUN_HARNESS"
    [ "$status" -eq 0 ]
    [ "$output" = $'08-safe-autofix-metadata\n13-mutation-preflight-lightweight' ]
}

@test "run-harness.sh: selects Minimization Path discovery scenarios" {
    run env HARNESS_LIST_PROMPTS_ONLY=1 HARNESS_SCENARIOS="15-cross-repo-fix-intake-capture,16-completed-cycle-explicit-reopen,17-local-gitignored-config-artifact" "$RUN_HARNESS"
    [ "$status" -eq 0 ]
    [ "$output" = $'15-cross-repo-fix-intake-capture\n16-completed-cycle-explicit-reopen\n17-local-gitignored-config-artifact' ]
}
