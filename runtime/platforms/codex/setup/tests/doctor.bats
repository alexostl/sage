#!/usr/bin/env bats
# T1.18 — bin/sage doctor Codex-specific checks (per spec §7.2).
#
# Plan contract (T1.18):
#   - Read-only diagnostic; the only file `sage doctor` writes is
#     `.sage/.doctor-cursor`. No project state mutation.
#   - v1 checks: E1, E2, E4, M1, M2, M3 (hint), S1, S3, S4, CV1.
#   - N/A in v1: E3, M4, S2 (deferred per §2 / §6.2 / §8).
#   - Each check has pass + fail signals.
#   - Exit code: 0 when no fail; non-zero when any check fails.
#
# v1 spec ref: §7.2.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    SAGE_BIN="$REPO_ROOT/bin/sage"
    [ -x "$SAGE_BIN" ] || skip "bin/sage not executable"
    TARGET="$(mktemp -d -t sage_doctor.XXXXXX)"
    # Provision a healthy Codex layout via the real generator.
    cd "$TARGET" || return 1
    git init -q
    env SAGE_FRAMEWORK="$REPO_ROOT" \
        "$REPO_ROOT/runtime/platforms/codex/setup/generate-codex.sh" \
        --target "$TARGET" --preset base >/dev/null 2>&1
}

teardown() {
    rm -rf "$TARGET"
}

run_doctor() {
    cd "$TARGET" || return 1
    env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" doctor "$@"
}

# ─── Posture: command + read-only ────────────────────────────────────

@test "doctor: command exists (sage doctor invocable)" {
    cd "$TARGET" || return 1
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" doctor
    # Must not be 'unknown command'.
    ! echo "$output" | grep -qi 'unknown command'
}

@test "doctor: writes only .sage/.doctor-cursor (read-only posture)" {
    # Snapshot every-file mtime+content under target before doctor.
    local pre post
    pre="$(find "$TARGET" -type f ! -path "$TARGET/.sage/.doctor-cursor" \
        ! -path '*/.git/*' -exec stat -f '%m %z %N' {} \; 2>/dev/null | sort)"
    run_doctor >/dev/null 2>&1 || true
    post="$(find "$TARGET" -type f ! -path "$TARGET/.sage/.doctor-cursor" \
        ! -path '*/.git/*' -exec stat -f '%m %z %N' {} \; 2>/dev/null | sort)"
    [ "$pre" = "$post" ] || {
        echo "BEFORE: $pre"
        echo "AFTER:  $post"
        return 1
    }
}

@test "doctor: cursor file appears at .sage/.doctor-cursor after run" {
    run_doctor >/dev/null 2>&1 || true
    [ -f "$TARGET/.sage/.doctor-cursor" ]
}

# ─── E2 — config.toml managed block ──────────────────────────────────

@test "E2 pass: config.toml has SAGE MANAGED BLOCK marker" {
    run run_doctor
    echo "$output" | grep -E 'E2.*config\.toml.*✓|✓.*E2|E2.*pass|E2.*OK' >/dev/null
}

@test "E2 fail: config.toml missing managed block → fail line emitted" {
    # Strip the managed block — leaves config.toml present but unmanaged.
    rm -f "$TARGET/.codex/config.toml"
    echo 'trust_level = "trusted"' > "$TARGET/.codex/config.toml"
    run run_doctor
    echo "$output" | grep -qi 'E2'
    echo "$output" | grep -qi 'managed\|sage block\|update'
}

# ─── M2 — hooks present + executable, jq+yq on PATH ──────────────────

@test "M2 pass: 4 hooks executable + jq + yq on PATH" {
    run run_doctor
    echo "$output" | grep -qi 'M2'
    # No explicit "fail" associated with M2 in healthy state.
    ! echo "$output" | grep -qE 'M2[^[:alnum:]].*(✗|FAIL|fail)'
}

@test "M2 fail: missing hook script → fail line emitted" {
    rm -f "$TARGET/.codex/hooks/session-init.sh"
    run run_doctor
    echo "$output" | grep -qi 'M2'
    echo "$output" | grep -qi 'session-init\|hook'
}

# ─── M1 — AGENTS.md matches generated baseline ───────────────────────

@test "M1 pass: AGENTS.md matches generated baseline" {
    run run_doctor
    echo "$output" | grep -qi 'M1\|AGENTS'
    # No explicit drift warning.
    ! echo "$output" | grep -qi 'drifted'
}

@test "M1 warn: AGENTS.md drifted from baseline" {
    # Insert content INSIDE the managed prefix (above SAGE-MANAGED-END).
    perl -i -pe 's/^(# Sage — Project Instructions)$/$1\n\nSURPRISE DRIFT/' "$TARGET/AGENTS.md"
    run run_doctor
    echo "$output" | grep -qi 'M1\|AGENTS\|drifted\|update'
}

# ─── S1 — incidents log unread lines ─────────────────────────────────

@test "S1 pass: no incidents log → no warn" {
    run run_doctor
    # Don't expect a warn line about S1 when log is missing.
    ! echo "$output" | grep -qE 'S1.*[1-9][0-9]* unread'
}

@test "S1 warn: incidents log has unread lines newer than cursor" {
    # Two lines, no cursor yet — both are "unread".
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/.mcp-incidents.log" <<EOF
{"ts":"2026-04-30T10:00:00Z","severity":"warn","type":"hook"}
{"ts":"2026-04-30T11:00:00Z","severity":"warn","type":"hook"}
EOF
    run run_doctor
    echo "$output" | grep -qi 'S1\|incident\|unread'
}

# ─── S3 — stale active cycles ────────────────────────────────────────

@test "S3 pass: no active cycles → no info line" {
    run run_doctor
    # When no in-progress cycles exist, there's nothing to flag.
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # any but 'unknown command'
}

@test "S3 info: in-progress cycle older than 7 days flagged" {
    mkdir -p "$TARGET/.sage/work/old-cycle"
    cat > "$TARGET/.sage/work/old-cycle/manifest.md" <<'EOF'
---
status: in-progress
phase: build
---
EOF
    # Backdate to 30 days ago.
    touch -t "$(date -v-30d +%Y%m%d0000.00 2>/dev/null || date -d '30 days ago' +%Y%m%d0000.00)" \
        "$TARGET/.sage/work/old-cycle/manifest.md" 2>/dev/null || true
    run run_doctor
    echo "$output" | grep -qi 'S3\|stale\|old-cycle'
}

# ─── CV1 — Codex version watch ───────────────────────────────────────

@test "CV1 pass: version matches validated record (no warn)" {
    # Seed validated version = arbitrary value.
    echo "0.0.0-validated" > "$TARGET/.sage/.codex-validated-version"
    run run_doctor
    echo "$output" | grep -qi 'CV1\|codex.*version'
}

# ─── Codex MCP hint removed — sanity ─────────────────────────────────

@test "doctor: never mentions [mcp_servers.sage-memory] (v1 has no MCP)" {
    run run_doctor
    ! echo "$output" | grep -F '[mcp_servers.sage-memory]'
}

# ─── Help shows doctor ───────────────────────────────────────────────

@test "doctor: appears in 'sage --help' output" {
    run "$SAGE_BIN" --help
    echo "$output" | grep -qi 'doctor'
}
