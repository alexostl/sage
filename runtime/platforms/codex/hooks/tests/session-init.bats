#!/usr/bin/env bats
# T1.4 — session-init.sh: SessionStart hook per spec §6.1 + §15.3.
#
# Plan contract (T1.4): prints banner, stat-checks
# `.sage/work/*/manifest.md`, emits cycle summary for in-progress/
# paused, emits last 3 decisions.md entries, exits 0 always.
#
# §15.3 smoke: print banner, no crash.

setup() {
    HOOK="$BATS_TEST_DIRNAME/../session-init.sh"
    [ -f "$HOOK" ] || skip "session-init.sh not found at $HOOK"
    [ -x "$HOOK" ] || skip "session-init.sh not executable"
    PROJECT_ROOT="$(mktemp -d -t session_init_bats.XXXXXX)"
    mkdir -p "$PROJECT_ROOT/.sage/work"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: build a stdin payload for SessionStart event.
make_payload() {
    local project_dir="$1"
    printf '{"session_id":"test-uuid","project_dir":"%s","ts":"2026-04-30T12:00:00Z"}' "$project_dir"
}

# Helper: write a manifest with frontmatter fields.
make_cycle() {
    local cycle="$1"
    local status="$2"
    local title="${3:-Test cycle $cycle}"
    local workflow="${4:-build}"
    local phase="${5:-implement}"
    local cycle_dir="$PROJECT_ROOT/.sage/work/$cycle"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "$cycle"
title: "$title"
workflow: $workflow
status: $status
phase: $phase
---
# $title
EOF
}

@test "session-init.sh: prints Sage banner to stdout (smoke §15.3)" {
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "sage"
}

@test "session-init.sh: empty .sage/work → exit 0, banner only, no crash" {
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    # No "in-progress" output for empty work dir
    ! echo "$output" | grep -q "in-progress"
}

@test "session-init.sh: in-progress cycle → emits one-line summary" {
    make_cycle "20260101-alpha" "in-progress" "Alpha feature" "build" "implement"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260101-alpha"
    echo "$output" | grep -q "Alpha feature"
}

@test "session-init.sh: paused cycle → emits summary line" {
    make_cycle "20260102-beta" "paused" "Beta feature" "fix" "diagnose"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260102-beta"
}

@test "session-init.sh: intake cycle → emits summary line" {
    make_cycle "20260106-intake" "intake" "Intake item" "intake" "intake"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260106-intake"
    echo "$output" | grep -q "intake"
}

@test "session-init.sh: completed cycle → no summary line emitted" {
    make_cycle "20260103-gamma" "completed" "Done feature" "build" "review"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "20260103-gamma"
}

@test "session-init.sh: mixed cycles → only in-progress + paused + intake listed" {
    make_cycle "20260101-done" "completed" "Done" "build" "review"
    make_cycle "20260102-active" "in-progress" "Active" "build" "implement"
    make_cycle "20260103-pause" "paused" "Paused" "fix" "diagnose"
    make_cycle "20260104-intake" "intake" "Intake" "intake" "intake"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260102-active"
    echo "$output" | grep -q "20260103-pause"
    echo "$output" | grep -q "20260104-intake"
    ! echo "$output" | grep -q "20260101-done"
}

@test "session-init.sh: does not emit decisions archive or raw evidence" {
    make_cycle "20260101-active" "in-progress" "Active" "build" "implement"
    mkdir -p "$PROJECT_ROOT/.sage/work/20260102-done/evidence"
    cat > "$PROJECT_ROOT/.sage/work/20260102-done/manifest.md" <<'EOF'
---
cycle_id: "20260102-done"
title: Completed item
workflow: build
status: completed
phase: completed
---
EOF
    cat > "$PROJECT_ROOT/.sage/work/20260102-done/evidence/raw.log" <<'EOF'
RAW_EVIDENCE_SHOULD_NOT_APPEAR
EOF
    cat > "$PROJECT_ROOT/.sage/decisions.md" <<'EOF'
# Decisions

### 2026-05-14 — Current Decision
Current context.
EOF
    cat > "$PROJECT_ROOT/.sage/decisions-archive.md" <<'EOF'
# Decisions Archive

### 2026-01-01 — Archived Secret
ARCHIVE_SHOULD_NOT_APPEAR
EOF
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260101-active"
    echo "$output" | grep -q "Current Decision"
    ! echo "$output" | grep -q "20260102-done"
    ! echo "$output" | grep -q "ARCHIVE_SHOULD_NOT_APPEAR"
    ! echo "$output" | grep -q "RAW_EVIDENCE_SHOULD_NOT_APPEAR"
}

@test "session-init.sh: emits last 3 decisions.md entries" {
    cat > "$PROJECT_ROOT/.sage/decisions.md" <<'EOF'
# Decisions

### 2026-04-30 — Decision E (newest)
Reason E.

### 2026-04-29 — Decision D
Reason D.

### 2026-04-28 — Decision C
Reason C.

### 2026-04-27 — Decision B
Reason B.

### 2026-04-26 — Decision A (oldest)
Reason A.
EOF
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Decision E"
    echo "$output" | grep -q "Decision D"
    echo "$output" | grep -q "Decision C"
    ! echo "$output" | grep -q "Decision B"
    ! echo "$output" | grep -q "Decision A"
}

@test "session-init.sh: missing decisions.md → no crash, exit 0" {
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "session-init.sh: empty decisions.md (header only) → no crash" {
    cat > "$PROJECT_ROOT/.sage/decisions.md" <<'EOF'
# Decisions

EOF
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "session-init.sh: malformed manifest (no status field) → skipped silently" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260104-broken"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: broken
---
EOF
    make_cycle "20260105-good" "in-progress" "Good" "build" "implement"
    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "20260105-good"
}

@test "session-init.sh: missing project_dir in payload → degrades, exit 0" {
    run bash -c "echo '{\"session_id\":\"x\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "session-init.sh: invalid JSON payload → degrades, exit 0 (never block session)" {
    run bash -c "echo 'not-json' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "session-init.sh: records dirty state baseline for current session" {
    cd "$PROJECT_ROOT"
    git init -q -b main
    git config user.email "test@test"
    git config user.name "test"
    echo "seed" > tracked.txt
    git add tracked.txt
    git commit -q -m "seed"
    echo "dirty" >> tracked.txt
    mkdir -p notes
    echo "new" > notes/new.txt

    payload="$(make_payload "$PROJECT_ROOT")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]

    log="$PROJECT_ROOT/.sage/.session-baseline.log"
    [ -f "$log" ]
    jq -e 'select(.kind == "session_baseline" and .session_id == "test-uuid")' "$log" >/dev/null
    jq -e 'select(.kind == "session_baseline") | .files[] | select(.path == "tracked.txt" and (.fingerprint | length > 0))' "$log" >/dev/null
    jq -e 'select(.kind == "session_baseline") | .files[] | select(.path == "notes/new.txt" and (.fingerprint | length > 0))' "$log" >/dev/null
}
