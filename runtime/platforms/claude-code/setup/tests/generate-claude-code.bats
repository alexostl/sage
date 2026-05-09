#!/usr/bin/env bats
# Claude Code generator regression coverage for the compact Alex-native contract.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-claude-code.sh"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t claude_codegen.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

generate_claude() {
    env SAGE_FRAMEWORK_DIR="$REPO_ROOT" bash "$GEN" "$TARGET"
}

@test "claude generator: CLAUDE.md carries compact Alex-native contract" {
    run generate_claude
    [ "$status" -eq 0 ]
    grep -q 'Alex-native operating contract' "$TARGET/CLAUDE.md"
    grep -q 'Treść prozatorską nowych sekcji w `.sage` pisz po' "$TARGET/CLAUDE.md"
    grep -q 'starszego angielskiego pliku' "$TARGET/CLAUDE.md"
    grep -q 'jedno pytanie naraz' "$TARGET/CLAUDE.md"
    grep -q '1-3 klikalne linki' "$TARGET/CLAUDE.md"
    grep -q '\[C\] Checkpointed implementation' "$TARGET/CLAUDE.md"
    grep -q '\[F\] Full autonomous implementation' "$TARGET/CLAUDE.md"
}

@test "claude generator: build and architect commands carry workflow-specific Alex-native guidance" {
    run generate_claude
    [ "$status" -eq 0 ]
    grep -q 'Alex-native operating contract' "$TARGET/.claude/commands/build.md"
    grep -q '\[C\] Checkpointed implementation' "$TARGET/.claude/commands/build.md"
    grep -q '\[F\] Full autonomous implementation' "$TARGET/.claude/commands/build.md"
    grep -q 'partial-guardrail risk' "$TARGET/.claude/commands/build.md"

    grep -q 'Alex-native operating contract' "$TARGET/.claude/commands/architect.md"
    grep -q 'older English files' "$TARGET/.claude/commands/architect.md"
    grep -q 'jedno pytanie naraz' "$TARGET/.claude/commands/architect.md"
    grep -q '1-3 klikalne linki' "$TARGET/.claude/commands/architect.md"
}
