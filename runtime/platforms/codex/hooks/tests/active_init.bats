#!/usr/bin/env bats
# T1.2 — lib/active_init.sh: return newest in-progress cycle path.
#
# Plan contract (T1.2): single in-progress → returns path; no cycles
# → returns empty; multiple → returns newest mtime + writes warning
# to .sage/.skipped-checks.log.

setup() {
    LIB="$BATS_TEST_DIRNAME/../lib/active_init.sh"
    [ -f "$LIB" ] || skip "active_init.sh not found at $LIB"
    PROJECT_ROOT="$(mktemp -d -t active_init_bats.XXXXXX)"
    mkdir -p "$PROJECT_ROOT/.sage/work"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: write a manifest with given cycle id + status. Optional
# mtime offset in seconds (negative = older).
make_cycle() {
    local cycle="$1"
    local status="$2"
    local mtime_offset="${3:-0}"
    local cycle_dir="$PROJECT_ROOT/.sage/work/$cycle"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "$cycle"
status: $status
---
# $cycle
EOF
    if [ "$mtime_offset" != "0" ]; then
        # touch with offset for ordering test
        touch -t "$(date -j -v"${mtime_offset}"S +%Y%m%d%H%M.%S 2>/dev/null || date -d "$mtime_offset seconds" +%Y%m%d%H%M.%S)" "$cycle_dir/manifest.md" 2>/dev/null || true
    fi
}

@test "active_init_path: empty work dir → empty output" {
    # shellcheck disable=SC1090
    source "$LIB"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ -z "$result" ]
}

@test "active_init_path: no .sage/work dir at all → empty output" {
    # shellcheck disable=SC1090
    source "$LIB"
    rm -rf "$PROJECT_ROOT/.sage"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ -z "$result" ]
}

@test "active_init_path: single in-progress cycle → returns cycle dir path" {
    # shellcheck disable=SC1090
    source "$LIB"
    make_cycle "20260101-alpha" "in-progress"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260101-alpha" ]
}

@test "active_init_path: only completed cycles → empty output" {
    # shellcheck disable=SC1090
    source "$LIB"
    make_cycle "20260101-alpha" "completed"
    make_cycle "20260102-beta" "completed"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ -z "$result" ]
}

@test "active_init_path: mixed in-progress + completed → returns only in-progress" {
    # shellcheck disable=SC1090
    source "$LIB"
    make_cycle "20260101-alpha" "completed"
    make_cycle "20260102-beta" "in-progress"
    make_cycle "20260103-gamma" "completed"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260102-beta" ]
}

@test "active_init_path: multiple in-progress → returns newest mtime + writes warning" {
    # shellcheck disable=SC1090
    source "$LIB"
    make_cycle "20260101-old" "in-progress"
    sleep 1
    make_cycle "20260102-newer" "in-progress"
    sleep 1
    make_cycle "20260103-newest" "in-progress"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260103-newest" ]
    skip_log="$PROJECT_ROOT/.sage/.skipped-checks.log"
    [ -f "$skip_log" ]
    grep -q "multiple in-progress cycles" "$skip_log"
}

@test "active_init_path: manifest with no status field → skipped silently" {
    # shellcheck disable=SC1090
    source "$LIB"
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-broken"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: broken
---
EOF
    make_cycle "20260102-good" "in-progress"
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260102-good" ]
}

@test "active_init_path: BUG-F1-2 — manifest with realistic markdown body containing YAML-like content → still detected" {
    # F-1 Phase 1 BUG-F1-2 (re-introduced after first retraction was wrong):
    # yq parses multi-doc YAML; when the markdown body after the closing
    # `---` contains content that LOOKS like YAML mapping (e.g. `**Artifacts:**`
    # followed by `- brief.md: exists`), yq emits the correct frontmatter
    # values to stdout but then exits non-zero on the body. The `|| continue`
    # in active_init then discards the cycle.
    # Fix: extract frontmatter via manifest_yaml() before piping to yq, so
    # yq never sees the markdown body.
    # shellcheck disable=SC1090
    source "$LIB"
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-realistic"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-realistic"
status: in-progress
phase: plan
---

# Cycle: Realistic Manifest

## State

**Current phase:** plan — implementation pending.
**Artifacts:**
- brief.md: exists
- spec.md: exists
- plan.md: exists
- implementation: not-started

## Decisions so far

- Standard scope chosen by user.
EOF
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260101-realistic" ]
}

@test "active_init_path: BUG-F1-2 regression — flat YAML manifest (no fences) still detected" {
    # Some manifests in the wild use flat YAML (no `---` delimiters).
    # The frontmatter extractor's fallback path must keep working.
    # shellcheck disable=SC1090
    source "$LIB"
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-flat"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
cycle_id: "20260101-flat"
status: in-progress
phase: plan
EOF
    result="$(active_init_path "$PROJECT_ROOT")"
    [ "$result" = "$PROJECT_ROOT/.sage/work/20260101-flat" ]
}
