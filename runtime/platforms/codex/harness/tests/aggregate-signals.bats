#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    AGG="$REPO_ROOT/runtime/platforms/codex/harness/lib/aggregate-signals.sh"
    TARGET="$(mktemp -d -t sage_harness_target.XXXXXX)"
    TRANSCRIPTS="$(mktemp -d -t sage_harness_transcripts.XXXXXX)"
    BIN_DIR="$(mktemp -d -t sage_harness_bin.XXXXXX)"
    cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then
  echo "codex-test"
  exit 0
fi
exit 0
EOF
    chmod +x "$BIN_DIR/codex"
    export PATH="$BIN_DIR:$PATH"
    mkdir -p "$TARGET/.sage"
    cd "$TARGET" || return 1
    git init -q
    git config user.email "harness@sage.local"
    git config user.name "harness"
    echo seed > README.md
    git add README.md
    git commit -q -m seed
}

teardown() {
    rm -rf "$TARGET" "$TRANSCRIPTS" "$BIN_DIR"
}

write_release_blocker_transcripts() {
    jq -r '.scenarios[] | select(.release_blocker == true) | .prompt' \
        "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json" |
        while IFS= read -r prompt; do
            [ -n "$prompt" ] || continue
            printf '{"type":"assistant","message":"ok"}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
        done
}

@test "aggregate-signals: v1.1 release blocker signal reports missing transcripts" {
    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.total == 7' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing | length == 7' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.release_rule | test("cannot be marked complete")' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.release_rule | test("exit code 0")' >/dev/null
}

@test "aggregate-signals: failed codex transcript does not satisfy release blocker evidence" {
    jq -r '.scenarios[] | select(.release_blocker == true) | .prompt' \
        "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json" |
        while IFS= read -r prompt; do
            [ -n "$prompt" ] || continue
            printf '{"type":"turn.failed"}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            printf '1\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl.exit"
        done
    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing | length == 7' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[0].exit_code == "1"' >/dev/null
}

@test "aggregate-signals: every v1.1 scenario prompt exists" {
    jq -r '.scenarios[].prompt' "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json" |
        while IFS= read -r prompt; do
            [ -f "$REPO_ROOT/runtime/platforms/codex/harness/prompts/$prompt" ] || {
                echo "missing prompt: $prompt"
                exit 1
            }
        done
}

@test "aggregate-signals: v1.1 release blocker signal is complete with all transcripts" {
    write_release_blocker_transcripts
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == true' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.present == 7' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing | length == 0' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.real_harness_required_for | index("memory reuse across sessions")' >/dev/null
}
