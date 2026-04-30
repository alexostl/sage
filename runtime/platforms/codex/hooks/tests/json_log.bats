#!/usr/bin/env bats
# T1.1 — lib/json_log.sh atomic JSON-line append helper.
#
# Plan contract (.sage/work/20260429-codex-port-rewrite/plan.md T1.1):
# 100 concurrent appenders each writing 10 lines, final file has 1000
# lines, all parseable as JSON; flock path + plain-append fallback
# both covered.

setup() {
    LIB="$BATS_TEST_DIRNAME/../lib/json_log.sh"
    [ -f "$LIB" ] || skip "json_log.sh not found at $LIB"
    TMP_DIR="$(mktemp -d -t json_log_bats.XXXXXX)"
    LOG_PATH="$TMP_DIR/test.log"
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "json_log_append: single line written and parses as JSON" {
    # shellcheck disable=SC1090
    source "$LIB"
    json_log_append "$LOG_PATH" '{"event":"test","n":1}'
    [ -f "$LOG_PATH" ]
    [ "$(wc -l < "$LOG_PATH" | tr -d ' ')" = "1" ]
    jq -e . < "$LOG_PATH" >/dev/null
}

@test "json_log_append: creates parent dir if missing" {
    # shellcheck disable=SC1090
    source "$LIB"
    nested="$TMP_DIR/deep/nested/path/x.log"
    json_log_append "$nested" '{"x":1}'
    [ -f "$nested" ]
}

@test "json_log_append: 100 concurrent appenders × 10 lines = 1000 valid JSON lines (default path)" {
    # shellcheck disable=SC1090
    source "$LIB"
    for i in $(seq 1 100); do
        (
            for j in $(seq 1 10); do
                json_log_append "$LOG_PATH" "{\"i\":$i,\"j\":$j}"
            done
        ) &
    done
    wait
    line_count=$(wc -l < "$LOG_PATH" | tr -d ' ')
    [ "$line_count" = "1000" ]
    # Every line must parse as JSON.
    while IFS= read -r line; do
        echo "$line" | jq -e . >/dev/null || { echo "BAD LINE: $line"; return 1; }
    done < "$LOG_PATH"
}

@test "json_log_append: 100 concurrent appenders × 10 lines = 1000 valid JSON lines (JSON_LOG_FORCE_PLAIN=1)" {
    # shellcheck disable=SC1090
    source "$LIB"
    export JSON_LOG_FORCE_PLAIN=1
    for i in $(seq 1 100); do
        (
            for j in $(seq 1 10); do
                json_log_append "$LOG_PATH" "{\"i\":$i,\"j\":$j}"
            done
        ) &
    done
    wait
    unset JSON_LOG_FORCE_PLAIN
    line_count=$(wc -l < "$LOG_PATH" | tr -d ' ')
    [ "$line_count" = "1000" ]
    while IFS= read -r line; do
        echo "$line" | jq -e . >/dev/null || { echo "BAD LINE: $line"; return 1; }
    done < "$LOG_PATH"
}

@test "json_log_append: appends not overwrites" {
    # shellcheck disable=SC1090
    source "$LIB"
    json_log_append "$LOG_PATH" '{"n":1}'
    json_log_append "$LOG_PATH" '{"n":2}'
    json_log_append "$LOG_PATH" '{"n":3}'
    [ "$(wc -l < "$LOG_PATH" | tr -d ' ')" = "3" ]
    [ "$(jq -s 'length' < "$LOG_PATH")" = "3" ]
}
