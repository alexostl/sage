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

release_blocker_count() {
    jq '[.scenarios[] | select(.release_blocker == true)] | length' \
        "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json"
}

write_release_blocker_transcripts() {
    jq -r '.scenarios[] | select(.release_blocker == true) | .prompt' \
        "$REPO_ROOT/runtime/platforms/codex/harness/v11-scenarios.json" |
        while IFS= read -r prompt; do
            [ -n "$prompt" ] || continue
            if [ "$prompt" = "03-build-out-of-scope.txt" ]; then
                printf '{"type":"assistant","message":"Sage: BLOCKING outside cycle scope. Next legal move: use sage:continue or update the approved manifest scope first."}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            elif [ "$prompt" = "12-full-autonomous-key-assumption.txt" ]; then
                printf '{"type":"assistant","message":"Sage: [F] means executing the approved plan without checkpoints, but a key assumption changed. I am stopping for a checkpoint decision before changing user-visible behavior."}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            elif [ "$prompt" = "04-fix-trigger.txt" ]; then
                printf '{"type":"assistant","message":"A fix cycle is required here: diagnosis/scope gate before changing AGENTS.md."}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            elif [ "$prompt" = "11-bug-report-no-fix.txt" ]; then
                printf '{"type":"assistant","message":"Zapisuję zgłoszony błąd jako finding bez implementacji."}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            else
                printf '{"type":"assistant","message":"ok"}\n' > "$TRANSCRIPTS/${prompt%.txt}.jsonl"
            fi
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
    expected="$(release_blocker_count)"
    echo "$output" | jq -e --argjson expected "$expected" '.signals.v11_release_blocker_harness.total == $expected' >/dev/null
    echo "$output" | jq -e --argjson expected "$expected" '.signals.v11_release_blocker_harness.missing | length == $expected' >/dev/null
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
    expected="$(release_blocker_count)"
    echo "$output" | jq -e --argjson expected "$expected" '.signals.v11_release_blocker_harness.missing | length == $expected' >/dev/null
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
    expected="$(release_blocker_count)"
    echo "$output" | jq -e --argjson expected "$expected" '.signals.v11_release_blocker_harness.present == $expected' >/dev/null
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

@test "aggregate-signals: fix-trigger scenario fails if AGENTS.md changed directly" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.changed_files = ["AGENTS.md"]' "$TRANSCRIPTS/04-fix-trigger.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/04-fix-trigger.jsonl.state.json"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "04-fix-trigger") | .rubric_failures[] | test("forbidden changed file pattern")' >/dev/null
}

@test "aggregate-signals: blocked-mutation scenario fails if src files changed" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.changed_files = ["src/notes/random.md"]' "$TRANSCRIPTS/03-build-out-of-scope.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/03-build-out-of-scope.jsonl.state.json"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "03-blocked-mutation-next-legal-move") | .rubric_failures[] | test("forbidden changed file pattern")' >/dev/null
}

@test "aggregate-signals: blocked-mutation scenario fails on unclaimed or bypass incidents" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.incidents = [
        {"kind":"unclaimed_change","file":".sage/work/20260510-random-note/manifest.md"},
        {"kind":"bypass_mutation","file":"src/notes/random.md"}
    ]' "$TRANSCRIPTS/03-build-out-of-scope.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/03-build-out-of-scope.jsonl.state.json"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e 'any(.signals.v11_release_blocker_harness.missing[] | select(.id == "03-blocked-mutation-next-legal-move") | .rubric_failures[]; test("forbidden audit kind present: unclaimed_change"))' >/dev/null
    echo "$output" | jq -e 'any(.signals.v11_release_blocker_harness.missing[] | select(.id == "03-blocked-mutation-next-legal-move") | .rubric_failures[]; test("forbidden audit kind present: bypass_mutation"))' >/dev/null
}

@test "aggregate-signals: blocked/recovery release blocker cannot have empty rubric" {
    local fake_fw
    fake_fw="$(mktemp -d -t sage_fake_framework.XXXXXX)"
    mkdir -p "$fake_fw/runtime/platforms/codex/harness"
    cat > "$fake_fw/runtime/platforms/codex/harness/v11-scenarios.json" <<'EOF'
{
  "policy": {
    "release_rule": "cannot be marked complete"
  },
  "scenarios": [
    {
      "id": "empty-blocked-rubric",
      "prompt": "empty-blocked-rubric.txt",
      "release_blocker": true,
      "claim": "blocked mutation returns a recovery message",
      "state_rubric": {}
    }
  ]
}
EOF
    printf '{"type":"assistant","message":"Sage: BLOCKING. Next legal move."}\n' > "$TRANSCRIPTS/empty-blocked-rubric.jsonl"
    printf '0\n' > "$TRANSCRIPTS/empty-blocked-rubric.jsonl.exit"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$fake_fw"
    rm -rf "$fake_fw"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "empty-blocked-rubric") | .rubric_failures[] | test("empty rubric")' >/dev/null
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
    expected="$(release_blocker_count)"
    echo "$output" | jq -e --argjson expected "$expected" '.signals."7_l1_bypass".total == $expected' >/dev/null
}

@test "aggregate-signals: bug-report-no-fix fails if implementation files change" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    jq '.changed_files = ["bin/sage"]' "$TRANSCRIPTS/11-bug-report-no-fix.jsonl.state.json" \
        > "$TRANSCRIPTS/state.tmp"
    mv "$TRANSCRIPTS/state.tmp" "$TRANSCRIPTS/11-bug-report-no-fix.jsonl.state.json"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "11-bug-report-no-fix") | .rubric_failures[] | test("forbidden changed file pattern")' >/dev/null
}

@test "aggregate-signals: bug-report-no-fix fails if transcript mentions parent repo .sage writes" {
    write_release_blocker_transcripts
    write_release_blocker_states
    for f in "$TRANSCRIPTS"/*.jsonl; do
        printf '0\n' > "$f.exit"
    done
    printf '{"type":"item.completed","item":{"type":"file_change","changes":[{"path":"%s/.sage/decisions.md","kind":"update"}]}}\n' "$REPO_ROOT" \
        >> "$TRANSCRIPTS/11-bug-report-no-fix.jsonl"

    run "$AGG" "$TARGET" "$TRANSCRIPTS" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.complete == false' >/dev/null
    echo "$output" | jq -e '.signals.v11_release_blocker_harness.missing[] | select(.id == "11-bug-report-no-fix") | .rubric_failures[] | test("forbidden transcript pattern")' >/dev/null
}
