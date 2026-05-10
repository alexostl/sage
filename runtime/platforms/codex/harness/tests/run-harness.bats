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
    grep -q -- 'service_tier="fast"' "$RUN_HARNESS"
    grep -q -- 'trust_level=\\"trusted\\"' "$RUN_HARNESS"
    ! grep -q -- '--ignore-user-config' "$RUN_HARNESS"
}
