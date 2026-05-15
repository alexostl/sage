#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    source "$REPO_ROOT/runtime/platforms/codex/harness/lib/log-parser.sh"
    TMP_DIR="$(mktemp -d -t sage_harness_log_parser.XXXXXX)"
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "log parser: real markdown auto-fix log emits safe_auto_fix" {
    local log="$TMP_DIR/.auto-fixes.log"
    cat > "$log" <<'EOF'
## 2026-05-10 14:10 - severity: low

- detected_state: manifest scope missing docs decision path
- why_safe: metadata-only repair
- changed: added one docs path to scope
- resulting_state: legal documentation write
- next_legal_move: write the docs decision
EOF

    run read_json_or_key_value_log "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "low"' >/dev/null
}

@test "log parser: start line ignores previous markdown entries" {
    local log="$TMP_DIR/.auto-fixes.log"
    cat > "$log" <<'EOF'
## 2026-05-10 14:10 - severity: low

- detected_state: old entry

## 2026-05-10 14:20 - severity: medium

- detected_state: new entry
EOF

    run read_json_or_key_value_log "$log" 5
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "medium"' >/dev/null
}

@test "log parser: pipe-delimited kind format still works" {
    local log="$TMP_DIR/.auto-fixes.log"
    printf '2026-05-10T12:00:00Z | kind=safe_auto_fix | severity=info | detected_state=metadata repair\n' > "$log"

    run read_json_or_key_value_log "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "info"' >/dev/null
}

@test "log parser: bracket heading safe-auto-fix format emits safe_auto_fix" {
    local log="$TMP_DIR/.auto-fixes.log"
    cat > "$log" <<'EOF'
[2026-05-15T00:32:00+02:00] severity=info type=safe-auto-fix
detected_state: manifest scope missing docs decision path
why_safe: metadata-only repair
what_changed: added one docs path to scope
resulting_state: legal documentation write
next_legal_move: write the docs decision
EOF

    run read_json_or_key_value_log "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "info"' >/dev/null
}

@test "log parser: bullet auto-fix log format emits safe_auto_fix" {
    local log="$TMP_DIR/.auto-fixes.log"
    cat > "$log" <<'EOF'
# Auto Fixes

- 2026-05-15 05:24 CEST
  detected_state: missing same-cycle documentation scope
  why_safe: capture-only metadata repair
  changed: created minimal manifest
  resulting_state: documentation write is legal
  severity: low
  next_legal_move: write the ADR
EOF

    run read_json_or_key_value_log "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "safe_auto_fix"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "low"' >/dev/null
}

@test "log parser: json lines pass through unchanged" {
    local log="$TMP_DIR/.mcp-incidents.log"
    printf '{"kind":"bypass_mutation","severity":"critical"}\n' > "$log"

    run read_json_or_key_value_log "$log" 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 1' >/dev/null
    echo "$output" | jq -e '.[0].kind == "bypass_mutation"' >/dev/null
    echo "$output" | jq -e '.[0].severity == "critical"' >/dev/null
}
