#!/usr/bin/env bats
# T1.14 — Stage 7: deploy skills to `<target>/.agents/skills/`.
#
# Plan contract (T1.14):
#   - For every public workflow deployed at `sage/core/workflows/<wf>.workflow.md`,
#     emit a Codex skill loader at
#     `<target>/.agents/skills/sage:<wf>/SKILL.md` with:
#       * frontmatter `name: sage:<wf>`
#       * frontmatter `description: <Tier C preamble>` (≤300 chars,
#         extracted via lib/extract-preamble.sh from T1.8)
#       * body referring to the source workflow file
#   - 16 stubs total (the 16 public workflows currently on disk).
#   - Re-run is idempotent (same content, no diff).
#   - Stage 7 fails when SAGE_FRAMEWORK invalid.
#
# v1 spec ref: §4 Stage 7, §5 Tier C.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage7_skills.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage7() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset base --stage 7
}

@test "stage7: creates .agents/skills/ directory" {
    run run_stage7
    [ "$status" -eq 0 ]
    [ -d "$TARGET/.agents/skills" ]
}

@test "stage7: deploys 16 workflow loader skills" {
    run_stage7
    local count
    count="$(find "$TARGET/.agents/skills" -mindepth 1 -maxdepth 1 -type d -name 'sage:*' | wc -l | tr -d ' ')"
    [ "$count" = "16" ]
}

@test "stage7: every public workflow has a loader stub" {
    run_stage7
    for wf in build fix architect research design analyze sage qa design-review reflect continue learn status review map autoresearch; do
        [ -f "$TARGET/.agents/skills/sage:$wf/SKILL.md" ] || {
            echo "MISSING: sage:$wf/SKILL.md"
            return 1
        }
    done
}

@test "stage7: each SKILL.md has name field matching sage:<wf>" {
    run_stage7
    for wf in build fix architect research design analyze sage qa design-review reflect continue learn status review map autoresearch; do
        local f="$TARGET/.agents/skills/sage:$wf/SKILL.md"
        local name
        name="$(awk '/^---$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")"
        [ "$name" = "sage:$wf" ] || {
            echo "BAD name in $f: got '$name'"
            return 1
        }
    done
}

@test "stage7: each SKILL.md has non-empty description (≤300 chars)" {
    run_stage7
    for wf in build fix architect research design analyze sage qa design-review reflect continue learn status review map autoresearch; do
        local f="$TARGET/.agents/skills/sage:$wf/SKILL.md"
        local desc
        desc="$(awk '/^---$/{c++; next} c==1 && /^description:/{sub(/^description:[[:space:]]*[">]?[[:space:]]*/,""); print; exit}' "$f")"
        [ -n "$desc" ] || { echo "EMPTY description for sage:$wf"; return 1; }
        [ "${#desc}" -le 300 ] || { echo "OVERLONG description for sage:$wf (${#desc} chars)"; return 1; }
    done
}

@test "stage7: SKILL.md body references the source workflow path" {
    run_stage7
    grep -q 'sage/core/workflows/build.workflow.md' "$TARGET/.agents/skills/sage:build/SKILL.md"
}

@test "stage7: sage loader keeps router/entry-point discovery strong" {
    run_stage7
    grep -q 'Sage.s intelligent entry point' "$TARGET/.agents/skills/sage:sage/SKILL.md"
    grep -q 'Read and follow the full workflow definition' "$TARGET/.agents/skills/sage:sage/SKILL.md"
    grep -q 'sage/core/workflows/sage.workflow.md' "$TARGET/.agents/skills/sage:sage/SKILL.md"
}

@test "stage7: re-run produces identical output (idempotent)" {
    run_stage7
    cp -r "$TARGET/.agents/skills" "$TARGET/.agents/skills.first"
    run_stage7
    diff -r "$TARGET/.agents/skills.first" "$TARGET/.agents/skills" >/dev/null
}

@test "stage7: fails when SAGE_FRAMEWORK invalid" {
    run env SAGE_FRAMEWORK=/nonexistent "$GEN" \
        --target "$TARGET" --preset base --stage 7
    [ "$status" -ne 0 ]
}
