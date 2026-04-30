#!/usr/bin/env bats
# T1.17 — bin/sage wiring for the new Codex port (per spec §7.1).
#
# Plan contract (T1.17):
#   - `bin/sage init --platform codex` invokes new generate-codex.sh
#     and produces a valid Codex layout (Stage 10 sanity passes).
#   - Pre-flight check on jq + yq runs before generator; missing tool
#     fails fast with install hint.
#   - The "Codex MCP" hint block in `sage setup memory` is removed
#     (v1 ships no MCP server per §2 / §8).
#
# v1 spec ref: §7.1.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    SAGE_BIN="$REPO_ROOT/bin/sage"
    [ -x "$SAGE_BIN" ] || skip "bin/sage not executable"
    TARGET="$(mktemp -d -t binsage_wiring.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

# ─── E2E init smoke ──────────────────────────────────────────────────

@test "bin/sage init --platform codex --preset base produces valid Codex layout" {
    cd "$TARGET" || return 1
    git init -q
    # Non-interactive: --platform + --preset bypass select_platform/preset prompts.
    # Pipe "" so any stray prompt sees end-of-input.
    run env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" init --platform codex --preset base </dev/null
    [ "$status" -eq 0 ] || { echo "$output" | tail -40; return 1; }
    [ -f "$TARGET/AGENTS.md" ]
    [ -f "$TARGET/.codex/config.toml" ]
    [ -f "$TARGET/.codex/hooks.json" ]
    [ -x "$TARGET/.codex/hooks/session-init.sh" ]
    [ -x "$TARGET/.codex/hooks/pre-tool-validate.sh" ]
    [ -x "$TARGET/.codex/hooks/post-tool-check.sh" ]
    [ -x "$TARGET/.codex/hooks/turn-audit.sh" ]
    [ -d "$TARGET/.agents/skills" ]
    [ -f "$TARGET/.sage/decisions.md" ]
    [ -d "$TARGET/.sage/gates/scripts" ]
    [ -f "$TARGET/.sage/constitution.md" ]
}

@test "bin/sage init runs Stage 10 sanity sweep PASSED on the produced layout" {
    cd "$TARGET" || return 1
    git init -q
    env SAGE_FRAMEWORK="$REPO_ROOT" "$SAGE_BIN" init --platform codex --preset base </dev/null >/dev/null 2>&1
    # Re-run Stage 10 against the produced target — must pass.
    run env SAGE_FRAMEWORK="$REPO_ROOT" \
        "$REPO_ROOT/runtime/platforms/codex/setup/generate-codex.sh" \
        --target "$TARGET" --preset base --stage 10
    [ "$status" -eq 0 ]
}

# ─── Pre-flight: jq + yq ─────────────────────────────────────────────

@test "bin/sage init --platform codex fails fast when jq missing (with install hint)" {
    cd "$TARGET" || return 1
    git init -q
    # Build a sandbox PATH that lacks jq but keeps yq + coreutils.
    local sandbox
    sandbox="$(mktemp -d -t binsage_nojq.XXXXXX)"
    # Symlink in everything except jq.
    for tool in bash sh awk sed grep find git mktemp mkdir cp mv rm chmod date wc tr cut head tail ls cat env basename dirname diff cmp readlink stat tee perl python3 yq sort uniq col tput xargs touch hostname pwd uname id stty; do
        local where
        where="$(command -v "$tool" 2>/dev/null)" || continue
        ln -sf "$where" "$sandbox/$tool" 2>/dev/null || true
    done
    run env -i HOME="$HOME" PATH="$sandbox" SAGE_FRAMEWORK="$REPO_ROOT" \
        "$SAGE_BIN" init --platform codex --preset base </dev/null
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'jq'
    rm -rf "$sandbox"
}

@test "bin/sage init --platform codex fails fast when yq missing (with install hint)" {
    cd "$TARGET" || return 1
    git init -q
    local sandbox
    sandbox="$(mktemp -d -t binsage_noyq.XXXXXX)"
    for tool in bash sh awk sed grep find git mktemp mkdir cp mv rm chmod date wc tr cut head tail ls cat env basename dirname diff cmp readlink stat tee perl python3 jq sort uniq col tput xargs touch hostname pwd uname id stty; do
        local where
        where="$(command -v "$tool" 2>/dev/null)" || continue
        ln -sf "$where" "$sandbox/$tool" 2>/dev/null || true
    done
    run env -i HOME="$HOME" PATH="$sandbox" SAGE_FRAMEWORK="$REPO_ROOT" \
        "$SAGE_BIN" init --platform codex --preset base </dev/null
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'yq'
    rm -rf "$sandbox"
}

# ─── Codex MCP hint block removed ────────────────────────────────────

@test "bin/sage setup memory no longer prints '[mcp_servers.sage-memory]' Codex branch" {
    # v1 spec §7.1: the Codex-specific MCP hint block is removed since
    # v1 ships no MCP server. The literal sage-memory MCP TOML block
    # should not appear in the bin/sage source any more.
    ! grep -F '[mcp_servers.sage-memory]' "$SAGE_BIN"
}
