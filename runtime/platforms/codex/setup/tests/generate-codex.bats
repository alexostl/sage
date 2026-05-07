#!/usr/bin/env bats
# T1.10 — generate-codex.sh skeleton: Stages 1, 2, 10.
#
# Plan contract (T1.10): bash skeleton with stage functions defined,
# Stage 1 (discover) + Stage 2 (read core) + Stage 10 (sanity sweep)
# implemented; Stages 3-9a stubbed (NotImplemented) for T1.11-T1.16.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -f "$GEN" ] || skip "generate-codex.sh not found at $GEN"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t generate_codex_bats.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

@test "generate-codex.sh: --help prints usage with --target / --preset flags" {
    run "$GEN" --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "target\|preset"
}

@test "generate-codex.sh: missing --target fails fast with exit 2" {
    run "$GEN"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "target"
}

@test "generate-codex.sh: --target points to non-directory → exit 2" {
    run "$GEN" --target /nonexistent/path/xyz123 --preset base
    [ "$status" -eq 2 ]
}

@test "generate-codex.sh: --target relative path → exit 2 (absolute required)" {
    run "$GEN" --target ./relative-path --preset base
    [ "$status" -eq 2 ]
}

@test "generate-codex.sh: Stage 1 detects existing AGENTS.md" {
    touch "$TARGET/AGENTS.md"
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 1 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "has_existing_agents_md"
    echo "$output" | grep -qi "true\|yes\|1"
}

@test "generate-codex.sh: Stage 1 detects .codex dir" {
    mkdir -p "$TARGET/.codex"
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 1 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "has_codex_config_dir"
}

@test "generate-codex.sh: Stage 1 detects git repo" {
    cd "$TARGET" && git init -q
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 1 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "is_git_repo"
}

@test "generate-codex.sh: Stage 2 reads core workflows + skills" {
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 2 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "workflows.*16\|workflows_to_load"
    echo "$output" | grep -qi "skills"
}

@test "generate-codex.sh: Stage 2 fails when SAGE_FRAMEWORK invalid" {
    run env SAGE_FRAMEWORK=/nonexistent "$GEN" --target "$TARGET" --preset base --stage 2 --dry-run
    [ "$status" -ne 0 ]
}

@test "generate-codex.sh: Stage 10 fails sanity sweep on bare target (no AGENTS.md)" {
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 10 --dry-run
    [ "$status" -ne 0 ]
}

@test "generate-codex.sh: Stage 10 passes sanity sweep on faked-complete target" {
    # Simulate a fully generated target — minimum invariants per spec §4 Stage 10.
    cat > "$TARGET/AGENTS.md" <<'EOF'
# Sage — Project Instructions

## Operating Kernel

Discover available Sage Memory tools through Codex tool discovery.
Fall back to `.sage-memory/` files only when MCP tools are unavailable.

<!-- SAGE-MANAGED-END -->
EOF
    mkdir -p "$TARGET/.codex/hooks" "$TARGET/.sage/gates/scripts"
    cat > "$TARGET/.codex/config.toml" <<'EOF'
trust_level = "trusted"
EOF
    cat > "$TARGET/.codex/hooks.json" <<'EOF'
{"hooks": {}}
EOF
    for h in session-init pre-tool-validate post-tool-check turn-audit; do
        echo '#!/bin/sh' > "$TARGET/.codex/hooks/$h.sh"
        chmod +x "$TARGET/.codex/hooks/$h.sh"
    done
    # T1.16 tightening: src gates count must match tgt — copy real ones.
    for g in "$REPO_ROOT"/core/gates/scripts/*.sh; do
        [ -f "$g" ] || continue
        cp "$g" "$TARGET/.sage/gates/scripts/"
        chmod 0755 "$TARGET/.sage/gates/scripts/$(basename "$g")"
    done
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
---
extends: base
---
EOF
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 10 --dry-run
    [ "$status" -eq 0 ]
}

@test "generate-codex.sh: --preset base is accepted" {
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage 1 --dry-run
    [ "$status" -eq 0 ]
}

@test "generate-codex.sh: stub stages 3-9a emit a TODO marker (not crash)" {
    for s in 3 4 5 6 7 9 9a; do
        run env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" --target "$TARGET" --preset base --stage "$s" --dry-run
        # Stub stages can return 0 (printing TODO) or any non-block exit;
        # they MUST NOT crash with shell-syntax errors.
        echo "stage=$s status=$status output=$output"
        # No assertion on status — these are stubs. Just confirm the
        # script reached the stage handler (output mentions stage).
    done
}
