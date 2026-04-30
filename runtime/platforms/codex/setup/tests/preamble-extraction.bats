#!/usr/bin/env bats
# T1.8 — preamble inline-extraction contract bats fixture.
#
# Plan contract (T1.8 LOCKED 2026-04-30 → option b):
#   - Extraction regex pulls first non-frontmatter paragraph from
#     core/workflows/<wf>.workflow.md correctly for ALL 16 public
#     workflows currently on disk.
#   - Regex tolerates leading blank lines + optional H1 `#` heading.
#   - Output ≤ 300 chars per spec §5 Tier C.
#   - No `core/preambles/` directory authored — extraction is inline.

setup() {
    EXTRACTOR="$BATS_TEST_DIRNAME/../lib/extract-preamble.sh"
    [ -f "$EXTRACTOR" ] || skip "extract-preamble.sh not found at $EXTRACTOR"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    WORKFLOWS_DIR="$REPO_ROOT/core/workflows"
    [ -d "$WORKFLOWS_DIR" ] || skip "core/workflows not found"
}

# Helper: list all 16 public workflow file basenames (without .workflow.md).
public_workflows() {
    cat <<'EOF'
build
fix
architect
research
design
analyze
sage
qa
design-review
reflect
continue
learn
status
review
map
autoresearch
EOF
}

@test "preamble: all 16 public workflow files exist on disk" {
    public_workflows | while IFS= read -r wf; do
        [ -f "$WORKFLOWS_DIR/$wf.workflow.md" ] || {
            echo "MISSING: $wf.workflow.md"
            return 1
        }
    done
}

@test "preamble: extractor produces non-empty output for every public workflow" {
    while IFS= read -r wf; do
        out="$(bash "$EXTRACTOR" "$WORKFLOWS_DIR/$wf.workflow.md")"
        [ -n "$out" ] || {
            echo "EMPTY for $wf"
            return 1
        }
    done < <(public_workflows)
}

@test "preamble: every extracted preamble is ≤ 300 chars (§5 Tier C)" {
    while IFS= read -r wf; do
        out="$(bash "$EXTRACTOR" "$WORKFLOWS_DIR/$wf.workflow.md")"
        len=${#out}
        if [ "$len" -gt 300 ]; then
            echo "OVER 300 chars ($len) for $wf"
            return 1
        fi
    done < <(public_workflows)
}

@test "preamble: extracted preamble does NOT contain frontmatter delimiters" {
    while IFS= read -r wf; do
        out="$(bash "$EXTRACTOR" "$WORKFLOWS_DIR/$wf.workflow.md")"
        if echo "$out" | grep -q '^---$'; then
            echo "frontmatter leaked for $wf: $out"
            return 1
        fi
    done < <(public_workflows)
}

@test "preamble: extracted preamble does NOT begin with '# ' (H1 stripped)" {
    while IFS= read -r wf; do
        out="$(bash "$EXTRACTOR" "$WORKFLOWS_DIR/$wf.workflow.md")"
        case "$out" in
            "# "*)
                echo "H1 leaked for $wf: $out"
                return 1
                ;;
        esac
    done < <(public_workflows)
}

@test "preamble: build.workflow.md → exact preamble (Tier C example)" {
    out="$(bash "$EXTRACTOR" "$WORKFLOWS_DIR/build.workflow.md")"
    [ "$out" = "Feature development guided by Sage." ]
}

@test "preamble: tolerates synthetic file with leading blank lines + H1" {
    tmp="$(mktemp -t preamble.XXXXXX)"
    cat > "$tmp" <<'EOF'
---
name: synthetic
---


# Synthetic Workflow

This is the preamble paragraph.

Section 2 starts here.
EOF
    out="$(bash "$EXTRACTOR" "$tmp")"
    [ "$out" = "This is the preamble paragraph." ]
    rm -f "$tmp"
}

@test "preamble: tolerates file without H1 (preamble immediately after frontmatter)" {
    tmp="$(mktemp -t preamble.XXXXXX)"
    cat > "$tmp" <<'EOF'
---
name: synthetic
---

Preamble line directly here.

Next section.
EOF
    out="$(bash "$EXTRACTOR" "$tmp")"
    [ "$out" = "Preamble line directly here." ]
    rm -f "$tmp"
}

@test "preamble: tolerates file with no frontmatter (just content)" {
    tmp="$(mktemp -t preamble.XXXXXX)"
    cat > "$tmp" <<'EOF'
# Header

The body paragraph.

More.
EOF
    out="$(bash "$EXTRACTOR" "$tmp")"
    [ "$out" = "The body paragraph." ]
    rm -f "$tmp"
}

@test "preamble: truncates content longer than 300 chars" {
    tmp="$(mktemp -t preamble.XXXXXX)"
    long_para="$(printf 'x%.0s' {1..400})"
    cat > "$tmp" <<EOF
---
name: long
---

$long_para
EOF
    out="$(bash "$EXTRACTOR" "$tmp")"
    [ "${#out}" -le 300 ]
    rm -f "$tmp"
}

@test "preamble: empty body → exit 1" {
    tmp="$(mktemp -t preamble.XXXXXX)"
    cat > "$tmp" <<'EOF'
---
name: empty
---

EOF
    run bash "$EXTRACTOR" "$tmp"
    [ "$status" -ne 0 ]
    rm -f "$tmp"
}

@test "preamble: no core/preambles/ directory exists (decision LOCKED option b)" {
    [ ! -d "$REPO_ROOT/core/preambles" ]
}
