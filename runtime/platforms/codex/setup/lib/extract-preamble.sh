#!/usr/bin/env bash
# extract-preamble.sh — extract first non-frontmatter paragraph from
# a `core/workflows/<wf>.workflow.md` file (Tier C preamble).
#
# Algorithm (decision LOCKED 2026-04-30 → option b: inline reading):
#   1. Skip YAML frontmatter (between leading `---` and next `---`).
#   2. Skip blank lines.
#   3. Skip optional H1 heading (`# ...`).
#   4. Skip blank lines.
#   5. Skip the optional generated "Artifact Language Contract" block.
#   6. Read until next blank line → that is the preamble paragraph.
#   7. Truncate output to 300 chars per spec §5 Tier C.
#
# Usage (sourced or executed):
#   extract_preamble <path-to-workflow-file>
#   # echoes preamble to stdout (≤ 300 chars), or exits 1 if empty.
#
# v1 spec ref: §5 Tier C.
# v1 plan ref: T1.8 (Group C — locked option b, no core/preambles/).

extract_preamble() {
    local file="$1"
    [ -f "$file" ] || return 1

    awk '
        BEGIN { state = "start" }
        # state machine:
        #   start    -> scanning preface; if first non-blank is "---", enter frontmatter
        #   frontmatter -> skip until closing "---", then post-frontmatter
        #   post-frontmatter -> skip blanks; if line is "# ..." skip H1; else go to body
        #   skip-artifact-contract -> skip generated language-contract boilerplate
        #   body -> accumulate until next blank line; then stop
        state == "start" {
            if ($0 ~ /^---[[:space:]]*$/) { state = "frontmatter"; next }
            if ($0 ~ /^[[:space:]]*$/) { next }
            state = "post-frontmatter"
            # fall through to post-frontmatter handling below
        }
        state == "frontmatter" {
            if ($0 ~ /^---[[:space:]]*$/) { state = "post-frontmatter" }
            next
        }
        state == "post-frontmatter" {
            if ($0 ~ /^[[:space:]]*$/) { next }
            if ($0 ~ /^# /) { state = "post-h1"; next }
            state = "body"
        }
        state == "post-h1" {
            if ($0 ~ /^[[:space:]]*$/) { next }
            if ($0 ~ /^##[[:space:]]+Artifact Language Contract[[:space:]]*$/) {
                state = "skip-artifact-contract"
                seen_contract_body = 0
                next
            }
            state = "body"
        }
        state == "skip-artifact-contract" {
            if ($0 ~ /^[[:space:]]*$/) {
                if (seen_contract_body == 1) {
                    state = "post-h1"
                }
                next
            }
            seen_contract_body = 1
            next
        }
        state == "body" {
            if ($0 ~ /^[[:space:]]*$/) { exit }
            buf = (buf == "" ? $0 : buf " " $0)
        }
        END {
            if (buf == "") exit 1
            if (length(buf) > 300) buf = substr(buf, 1, 300)
            print buf
        }
    ' "$file"
}

# When executed directly (not sourced), run on argv[1].
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    extract_preamble "$1"
fi
