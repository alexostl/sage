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

write_release_blocker_states() {
    jq -r '.scenarios[] | select(.release_blocker == true) | .prompt' \
        "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json" |
        while IFS= read -r prompt; do
            [ -n "$prompt" ] || continue
            base="$TRANSCRIPTS/${prompt%.txt}.jsonl"
            auto_fixes='[]'
            changed_files='[]'
            case "$prompt" in
                06-action-creates-or-resumes-manifest.txt)
                    changed_files='[".sage/work/20260507-harness-action/manifest.md"]' ;;
                08-safe-autofix-metadata.txt)
                    auto_fixes='[{"kind":"safe_auto_fix"}]' ;;
            esac
            jq -n --arg prompt "${prompt%.txt}" --argjson auto_fixes "$auto_fixes" --argjson changed_files "$changed_files" '{
                prompt: $prompt,
                model: "gpt-5.4",
                reasoning_effort: "medium",
                target_mode: "dummy-project",
                exit_code: 0,
                files: [".sage/decisions.md"],
                manifests: [],
                new_manifests: [],
                changed_files: $changed_files,
                incidents: [],
                auto_fixes: $auto_fixes
            }' > "$base.state.json"
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
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == true' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.present == 7' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing | length == 0' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.real_harness_required_for | index("memory reuse across sessions")' >/dev/null
    echo "$output" | jq -e '.model_profile.model == "gpt-5.4"' >/dev/null
    echo "$output" | jq -e '.model_profile.reasoning_effort == "medium"' >/dev/null
    echo "$output" | jq -e '.model_profile.forbidden_models | index("gpt-5.5")' >/dev/null
}

@test "aggregate-signals: state rubric failures block release blocker completion" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.changed_files = []' "$TRANSCRIPTS/06-action-creates-or-resumes-manifest.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/06-action-creates-or-resumes-manifest.jsonl.state.json"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "06-action-creates-or-resumes-manifest") | .rubric_failures[] | test("missing changed file pattern")' >/dev/null
}

@test "aggregate-signals: target-wide audit log does not satisfy scenario audit kind" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.auto_fixes = []' "$TRANSCRIPTS/08-safe-autofix-metadata.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/08-safe-autofix-metadata.jsonl.state.json"
    printf '2026-05-07 19:07:57 +0200 | kind=safe_auto_fix | severity=info | detected_state=metadata repair\n' \
        > "$TARGET/.sage/.auto-fixes.log"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "08-safe-autofix-metadata") | .rubric_failures[] | test("missing audit kind")' >/dev/null
}

@test "aggregate-signals: signal 7 uses state snapshots before noisy harness commits" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    echo changed > README.md
    git add README.md
    git commit -q -m "harness: synthetic session"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals."7_l1_bypass".count == 0' >/dev/null
    echo "$output" | jq -e '.signals."7_l1_bypass".total == 7' >/dev/null
}
