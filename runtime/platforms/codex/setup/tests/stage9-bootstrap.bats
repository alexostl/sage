#!/usr/bin/env bats
# T1.15 — Stage 9 (.sage skeleton) + Stage 9a (gates scripts copy).
#
# Plan contract (T1.15):
#   Stage 9: when `<target>/.sage/` is absent, create:
#     - `.sage/decisions.md` with `# Decisions` header
#     - `.sage/{docs,work,gates}/.gitkeep`
#   When `.sage/` already exists, leave it alone (project-owned state).
#   v1 addendum (closes B3): when `<target>/.sage/constitution.md` is
#   absent, write a stub with frontmatter `extends: <preset>` and an
#   "Add project-specific overrides here" body.
#
#   Stage 9a (closes B2): copy every `*.sh` from
#   `$SAGE_FRAMEWORK/core/gates/scripts/` to `<target>/.sage/gates/scripts/`
#   with mode 0755. On update flow with locally-modified target file,
#   backup as `<name>.user-edit-backup-<iso-ts>` then overwrite. Empty
#   source dir → info message, exit 0 (no error).
#
# v1 spec ref: §4 Stage 9 + Stage 9a, §15.2 (B2/B3).

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage9_bootstrap.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage() {
    local stage="$1"
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset base --stage "$stage"
}

# ─── Stage 9 ─ skeleton bootstrap ────────────────────────────────────

@test "stage9: creates .sage/decisions.md when .sage/ missing" {
    run run_stage 9
    [ "$status" -eq 0 ]
    [ -f "$TARGET/.sage/decisions.md" ]
}

@test "stage9: decisions.md contains '# Decisions' header" {
    run_stage 9
    grep -q '^# Decisions' "$TARGET/.sage/decisions.md"
}

@test "stage9: creates .gitkeep in docs/, work/, gates/" {
    run_stage 9
    [ -f "$TARGET/.sage/docs/.gitkeep" ]
    [ -f "$TARGET/.sage/work/.gitkeep" ]
    [ -f "$TARGET/.sage/gates/.gitkeep" ]
}

@test "stage9: leaves existing .sage/ alone (preserves user content)" {
    mkdir -p "$TARGET/.sage/work/in-flight"
    echo "# Decisions" > "$TARGET/.sage/decisions.md"
    echo "user content" >> "$TARGET/.sage/decisions.md"
    echo "active" > "$TARGET/.sage/work/in-flight/spec.md"
    run_stage 9
    grep -q "user content" "$TARGET/.sage/decisions.md"
    [ -f "$TARGET/.sage/work/in-flight/spec.md" ]
}

@test "stage9: stubs .sage/constitution.md with 'extends: <preset>' (B3)" {
    run_stage 9
    [ -f "$TARGET/.sage/constitution.md" ]
    grep -qE '^extends:[[:space:]]*base$' "$TARGET/.sage/constitution.md"
}

@test "stage9: constitution stub has 'extends: <preset>' inside frontmatter" {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset enterprise --stage 9
    grep -qE '^extends:[[:space:]]*enterprise$' "$TARGET/.sage/constitution.md"
    # Frontmatter delimiters present.
    head -1 "$TARGET/.sage/constitution.md" | grep -q '^---$'
}

@test "stage9: stub heading uses '## Project Additions' (matches Stage 3 merger contract)" {
    # Stub-merger contract gap (T2.6): the bootstrap stub must teach
    # the user the SAME heading the Stage 3 user-overlay merger reads.
    # If these drift, users follow the stub and get nothing merged.
    run_stage 9
    grep -q '^## Project Additions' "$TARGET/.sage/constitution.md"
}

@test "stage9: leaves existing .sage/constitution.md alone" {
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/constitution.md" <<EOF
---
extends: enterprise
---

# user-customized constitution
EOF
    run_stage 9
    grep -q '# user-customized constitution' "$TARGET/.sage/constitution.md"
    grep -qE '^extends:[[:space:]]*enterprise$' "$TARGET/.sage/constitution.md"
}

# ─── Stage 9 — BUG-F1-4 gitignore for hook-only writers ─────────────

@test "stage9: BUG-F1-4 — fresh init creates .gitignore with hook-only writer entries" {
    # F-1 Phase 1 BUG-F1-4: doctor S4 flagged .sage/.mcp-incidents.log and
    # .sage/.session-mutations.log as bypass writes when they appeared in git
    # history. Root cause: missing .gitignore entries → `git add -A` swept
    # them in. Fix: stage 9 ensures these are gitignored.
    run run_stage 9
    [ "$status" -eq 0 ]
    [ -f "$TARGET/.gitignore" ]
    grep -q '^\.sage/\.mcp-incidents\.log$' "$TARGET/.gitignore"
    grep -q '^\.sage/\.session-mutations\.log$' "$TARGET/.gitignore"
    grep -q '^\.sage/\.skipped-checks\.log$' "$TARGET/.gitignore"
}

@test "stage9: BUG-F1-4 — existing .gitignore gets sentinel block appended; user lines preserved" {
    cat > "$TARGET/.gitignore" <<'EOF'
# user-managed
node_modules/
*.log
EOF
    run_stage 9
    grep -q '^# Sage hook artifacts' "$TARGET/.gitignore"
    grep -q '^# end Sage hook artifacts' "$TARGET/.gitignore"
    grep -q '^node_modules/$' "$TARGET/.gitignore"
    grep -q '^\*\.log$' "$TARGET/.gitignore"
    grep -q '^# user-managed$' "$TARGET/.gitignore"
}

@test "stage9: BUG-F1-4 — re-running init is idempotent (no duplicate sentinel block)" {
    run_stage 9
    run_stage 9
    local count
    count="$(grep -c '^# Sage hook artifacts' "$TARGET/.gitignore" || true)"
    [ "$count" = "1" ]
    count="$(grep -c '^\.sage/\.mcp-incidents\.log$' "$TARGET/.gitignore" || true)"
    [ "$count" = "1" ]
}

# ─── Stage 9a ─ gates scripts deploy ─────────────────────────────────

@test "stage9a: deploys all gates scripts from framework" {
    run run_stage 9a
    [ "$status" -eq 0 ]
    [ -d "$TARGET/.sage/gates/scripts" ]
    local src_count tgt_count
    src_count="$(find "$REPO_ROOT/core/gates/scripts" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')"
    tgt_count="$(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')"
    [ "$src_count" = "$tgt_count" ]
    [ "$src_count" -gt 0 ]
}

@test "stage9a: deployed scripts are mode 0755 (executable)" {
    run_stage 9a
    local script
    while IFS= read -r script; do
        [ -n "$script" ] || continue
        [ -x "$script" ] || { echo "NOT EXECUTABLE: $script"; return 1; }
    done < <(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh')
}

@test "stage9a: deployed scripts byte-identical to source on first install" {
    run_stage 9a
    local script base
    while IFS= read -r script; do
        [ -n "$script" ] || continue
        base="$(basename "$script")"
        cmp -s "$REPO_ROOT/core/gates/scripts/$base" "$script" || {
            echo "MISMATCH: $base"
            return 1
        }
    done < <(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh')
}

@test "stage9a: re-run with locally modified target file backs up + overwrites" {
    run_stage 9a
    local first
    first="$(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh' | head -1)"
    [ -n "$first" ]
    echo "# user tampered" >> "$first"
    run_stage 9a
    # Tampering removed.
    ! grep -q '# user tampered' "$first"
    # Backup exists.
    ls "$TARGET/.sage/gates/scripts"/*.user-edit-backup-* >/dev/null 2>&1
}

@test "stage9a: idempotent re-run (no edits) leaves no backup files" {
    run_stage 9a
    run_stage 9a
    ! ls "$TARGET/.sage/gates/scripts"/*.user-edit-backup-* >/dev/null 2>&1
}

@test "stage9a: empty source dir → info message, exit 0" {
    local fake_fw
    fake_fw="$(mktemp -d -t stage9a_emptyfw.XXXXXX)"
    mkdir -p "$fake_fw/core/gates/scripts" "$fake_fw/core/workflows" "$fake_fw/core/capabilities"
    run env SAGE_FRAMEWORK="$fake_fw" "$GEN" \
        --target "$TARGET" --preset base --stage 9a
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'no gate scripts'
    rm -rf "$fake_fw"
}

@test "stage9a: fails when SAGE_FRAMEWORK invalid" {
    run env SAGE_FRAMEWORK=/nonexistent "$GEN" \
        --target "$TARGET" --preset base --stage 9a
    [ "$status" -ne 0 ]
}
