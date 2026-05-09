#!/usr/bin/env bats
# T1.19 — bin/sage status (per spec §7.3 + ADR-9 v1).
#
# Plan contract (T1.19):
#   - Reads disk directly (no MCP — ADR-9 v1).
#   - Emits 4-block plain text output:
#     1. Aktywne cykle — title, workflow, phase, status, last update
#     2. Bramki pending — approval-pending hints
#     3. Ostatnie decyzje — last 3 entries from decisions.md
#     4. Zdrowie — short version of doctor (warn/fail counts)
#   - `--json` flag emits scriptable form.
#   - Bash test passes on target with 1 active cycle + 2 stale cycles.
#
# v1 spec ref: §7.3.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    SAGE_BIN="$REPO_ROOT/bin/sage"
    [ -x "$SAGE_BIN" ] || skip "bin/sage not executable"
    TARGET="$(mktemp -d -t sage_status.XXXXXX)"
    cd "$TARGET" || return 1
    git init -q
    env SAGE_FRAMEWORK="$REPO_ROOT" \
        "$REPO_ROOT/runtime/platforms/codex/setup/generate-codex.sh" \
        --target "$TARGET" --preset base >/dev/null 2>&1
}

teardown() {
    rm -rf "$TARGET"
}

run_status() {
    cd "$TARGET" || return 1
    env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" status "$@"
}

# Seed cycles: 1 active (recent), 2 stale (old).
seed_cycles() {
    mkdir -p "$TARGET/.sage/work/20260430-active"
    cat > "$TARGET/.sage/work/20260430-active/manifest.md" <<'EOF'
---
title: Active feature build
workflow: build
phase: implement
status: in-progress
updated: 2026-04-30
---
EOF
    mkdir -p "$TARGET/.sage/work/20260301-stale-a"
    cat > "$TARGET/.sage/work/20260301-stale-a/manifest.md" <<'EOF'
---
title: Stale build A
workflow: build
phase: spec
status: in-progress
updated: 2026-03-01
---
EOF
    mkdir -p "$TARGET/.sage/work/20260315-stale-b"
    cat > "$TARGET/.sage/work/20260315-stale-b/manifest.md" <<'EOF'
---
title: Stale fix B
workflow: fix
phase: investigate
status: in-progress
updated: 2026-03-15
---
EOF
    # Backdate the stale ones.
    touch -t "$(date -v-30d +%Y%m%d0000.00 2>/dev/null || date -d '30 days ago' +%Y%m%d0000.00)" \
        "$TARGET/.sage/work/20260301-stale-a/manifest.md" \
        "$TARGET/.sage/work/20260315-stale-b/manifest.md" 2>/dev/null || true
}

seed_paused_intake_cycles() {
    mkdir -p "$TARGET/.sage/work/20260430-active"
    cat > "$TARGET/.sage/work/20260430-active/manifest.md" <<'EOF'
---
title: Active feature build
workflow: build
phase: implement
status: in-progress
updated: 2026-04-30
---
EOF
    mkdir -p "$TARGET/.sage/work/20260501-paused"
    cat > "$TARGET/.sage/work/20260501-paused/manifest.md" <<'EOF'
---
title: Paused hook repair
workflow: fix
phase: diagnose
status: paused
updated: 2026-05-01
---
EOF
    mkdir -p "$TARGET/.sage/work/20260502-intake"
    cat > "$TARGET/.sage/work/20260502-intake/manifest.md" <<'EOF'
---
title: Intake status visibility
workflow: intake
phase: intake
status: intake
updated: 2026-05-02
---
EOF
}

# ─── Command exists + read-only ──────────────────────────────────────

@test "status: command exists (sage status invocable)" {
    cd "$TARGET" || return 1
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" status
    ! echo "$output" | grep -qi 'unknown command'
}

@test "status: read-only — no project files mutated" {
    seed_cycles
    local pre post
    pre="$(find "$TARGET" -type f ! -path '*/.git/*' ! -path "$TARGET/.sage/.doctor-cursor" \
        -exec sh -c 'stat -c '''%Y %s %n''' "$1" 2>/dev/null || stat -f '''%m %z %N''' "$1"' _ {} \; 2>/dev/null | sort)"
    run_status >/dev/null 2>&1 || true
    post="$(find "$TARGET" -type f ! -path '*/.git/*' ! -path "$TARGET/.sage/.doctor-cursor" \
        -exec sh -c 'stat -c '''%Y %s %n''' "$1" 2>/dev/null || stat -f '''%m %z %N''' "$1"' _ {} \; 2>/dev/null | sort)"
    [ "$pre" = "$post" ]
}

# ─── 4 blocks of plain text output ───────────────────────────────────

@test "status: prints Polish active cycles block" {
    seed_cycles
    run run_status
    echo "$output" | grep -qi 'Aktywne cykle'
}

@test "status: lists active cycle title + phase + status" {
    seed_cycles
    run run_status
    echo "$output" | grep -q 'Active feature build'
    echo "$output" | grep -qi 'implement'
    echo "$output" | grep -qi 'in-progress'
}

@test "status: lists ALL three in-progress cycles (active + 2 stale)" {
    seed_cycles
    run run_status
    echo "$output" | grep -q '20260430-active'
    echo "$output" | grep -q '20260301-stale-a'
    echo "$output" | grep -q '20260315-stale-b'
}

@test "status: prints paused/intake work in separate section with next action hint" {
    seed_paused_intake_cycles
    run run_status
    echo "$output" | grep -qi 'Aktywne cykle'
    echo "$output" | grep -q '20260430-active'
    echo "$output" | grep -qi 'paused'
    echo "$output" | grep -qi 'intake'
    echo "$output" | grep -q '20260501-paused'
    echo "$output" | grep -q '20260502-intake'
    echo "$output" | grep -qi 'sage:continue'
    echo "$output" | grep -qi 'zaparkowane'
    echo "$output" | grep -qi 'manifest-only'
    echo "$output" | grep -qi 'brak aktywnej implementacji'
}

@test "status: prints Polish pending gates block" {
    seed_cycles
    run run_status
    echo "$output" | grep -qi 'Bramki pending'
}

@test "status: prints Polish recent decisions block" {
    cat > "$TARGET/.sage/decisions.md" <<'EOF'
# Decisions

### 2026-04-30 — Decision A
First decision body.

### 2026-04-29 — Decision B
Second decision body.

### 2026-04-28 — Decision C
Third decision body.

### 2026-04-27 — Decision D
Fourth decision body.
EOF
    run run_status
    echo "$output" | grep -qi 'Ostatnie decyzje'
    echo "$output" | grep -q 'Decision A'
    echo "$output" | grep -q 'Decision B'
    echo "$output" | grep -q 'Decision C'
    # Only last 3 — D should NOT appear.
    ! echo "$output" | grep -q 'Decision D'
}

@test "status: prints Polish health summary block" {
    seed_cycles
    run run_status
    echo "$output" | grep -qi 'Zdrowie'
}

# ─── --json flag ─────────────────────────────────────────────────────

@test "status --json: emits valid JSON" {
    seed_cycles
    run run_status --json
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null
}

@test "status --json: has top-level keys cycles, gates, decisions, health" {
    seed_cycles
    run run_status --json
    echo "$output" | jq -e '.cycles' >/dev/null
    echo "$output" | jq -e '.gates' >/dev/null
    echo "$output" | jq -e '.decisions' >/dev/null
    echo "$output" | jq -e '.health' >/dev/null
}

@test "status --json: cycles array contains 3 in-progress entries" {
    seed_cycles
    run run_status --json
    local n
    n="$(echo "$output" | jq -r '.cycles | length')"
    [ "$n" = "3" ]
}

@test "status --json: includes active, paused, and intake cycles with status fields" {
    seed_paused_intake_cycles
    run run_status --json
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.cycles[] | select(.id == "20260430-active" and .status == "in-progress")' >/dev/null
    echo "$output" | jq -e '.cycles[] | select(.id == "20260501-paused" and .status == "paused")' >/dev/null
    echo "$output" | jq -e '.cycles[] | select(.id == "20260502-intake" and .status == "intake")' >/dev/null
}

@test "status --json: cycles entry includes id and status fields" {
    seed_cycles
    run run_status --json
    echo "$output" | jq -e '.cycles[0].id' >/dev/null
    echo "$output" | jq -e '.cycles[0].status' >/dev/null
}

# ─── Help mentions status ────────────────────────────────────────────

@test "status: appears in 'sage --help' output" {
    run "$SAGE_BIN" --help
    echo "$output" | grep -qi 'status'
}
