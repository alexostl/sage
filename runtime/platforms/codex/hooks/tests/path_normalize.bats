#!/usr/bin/env bats
# T2.7 follow-up — path_normalize.sh: canonicalize apply_patch DSL paths.
#
# Real-Codex bug surfaced by harness baseline 2026-04-30:
# Codex 0.126.0-alpha.15 emits ABSOLUTE paths in apply_patch DSL
# (e.g. /private/var/folders/.../target/AGENTS.md), while
# `git status --porcelain` emits relative paths (AGENTS.md). The
# bypass_mutation + claim_no_op + unclaimed_change comparisons all
# mismatch, producing 18 false incidents per 5-prompt harness run.
#
# Fix: normalize_path() strips cwd prefix (with optional macOS /private
# symlink prefix) so all comparisons happen in relative-to-cwd form.

setup() {
    LIB="$BATS_TEST_DIRNAME/../lib/path_normalize.sh"
    [ -f "$LIB" ] || skip "path_normalize.sh not found at $LIB"
    # shellcheck source=/dev/null
    . "$LIB"
}

@test "normalize_path: already relative — returned unchanged" {
    run normalize_path "AGENTS.md" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "AGENTS.md" ]
}

@test "normalize_path: relative subdir — returned unchanged" {
    run normalize_path "src/notes/random.md" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "src/notes/random.md" ]
}

@test "normalize_path: absolute under cwd — cwd prefix stripped" {
    run normalize_path "/tmp/project/AGENTS.md" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "AGENTS.md" ]
}

@test "normalize_path: absolute deep under cwd — cwd prefix stripped" {
    run normalize_path "/tmp/project/.sage/work/X/manifest.md" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = ".sage/work/X/manifest.md" ]
}

@test "normalize_path: macOS /private prefix — stripped (path has /private, cwd does not)" {
    # apply_patch DSL emits /private/var/folders/X/target/AGENTS.md;
    # cwd from payload is /var/folders/X/target — symlink-resolved variant
    # of the same dir. Comparison should yield AGENTS.md.
    run normalize_path "/private/var/folders/abc/target/AGENTS.md" "/var/folders/abc/target"
    [ "$status" -eq 0 ]
    [ "$output" = "AGENTS.md" ]
}

@test "normalize_path: macOS /private prefix — stripped (cwd has /private, path does not)" {
    # Inverse case — cwd canonicalized to /private/var/..., path raw /var/...
    run normalize_path "/var/folders/abc/target/src/notes/random.md" "/private/var/folders/abc/target"
    [ "$status" -eq 0 ]
    [ "$output" = "src/notes/random.md" ]
}

@test "normalize_path: absolute outside cwd — returned unchanged (out-of-scope path)" {
    run normalize_path "/etc/passwd" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "/etc/passwd" ]
}

@test "normalize_path: path equals cwd exactly — returned as '.'" {
    run normalize_path "/tmp/project" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "." ]
}

@test "normalize_path: empty path — returned empty (no crash on edge case)" {
    run normalize_path "" "/tmp/project"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "normalize_path: trailing slash on cwd tolerated" {
    run normalize_path "/tmp/project/AGENTS.md" "/tmp/project/"
    [ "$status" -eq 0 ]
    [ "$output" = "AGENTS.md" ]
}
