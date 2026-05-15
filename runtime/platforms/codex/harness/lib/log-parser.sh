#!/usr/bin/env bash
# log-parser.sh - shared harness audit-log parser helpers.

read_json_or_key_value_log() {
    local file="${1:?log file required}"
    local start_line="${2:-1}"
    local tmp
    tmp="$(mktemp)"
    if [ -f "$file" ]; then
        tail -n +"$start_line" "$file" > "$tmp"
    fi

    if jq -sc '.' "$tmp" >/dev/null 2>&1; then
        jq -sc '.' "$tmp"
        rm -f "$tmp"
        return
    fi

    awk -F'|' -v file="$file" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        function emit_entry() {
            if (kind != "") {
                print kind "\t" severity
            }
            kind = ""
            severity = ""
        }
        function severity_from_heading(heading) {
            if (match(heading, /severity[:=][[:space:]]*[^[:space:]]+/)) {
                value = substr(heading, RSTART, RLENGTH)
                sub(/^severity[:=][[:space:]]*/, "", value)
                return value
            }
            return ""
        }
        BEGIN {
            is_auto_fix_log = (file ~ /(^|\/)\.auto-fixes\.log$/)
        }
        {
            normalized = tolower($0)
            if (is_auto_fix_log && normalized ~ /(^|[[:space:]])(type|kind)=safe[-_]auto[-_]fix($|[[:space:]])/) {
                emit_entry()
                kind = "safe_auto_fix"
                severity = severity_from_heading(normalized)
                next
            }
            if (is_auto_fix_log && $0 ~ /^-[[:space:]]+[0-9][0-9][0-9][0-9]([- ][0-9]|$)/) {
                emit_entry()
                kind = "safe_auto_fix"
                severity = severity_from_heading(normalized)
                next
            }
            if ($0 ~ /^#{2,6}[[:space:]]+/) {
                emit_entry()
                heading = normalized
                if (is_auto_fix_log || heading ~ /safe/ || heading ~ /auto-fix/ || heading ~ /scope repair/) {
                    kind = "safe_auto_fix"
                    severity = severity_from_heading(heading)
                }
                next
            }
            if (kind != "" && normalized ~ /^-?[[:space:]]*severity[:=]/) {
                severity = normalized
                sub(/^-?[[:space:]]*severity[:=][[:space:]]*/, "", severity)
                next
            }
            pipe_kind = ""
            pipe_severity = ""
            for (i = 1; i <= NF; i++) {
                part = trim($i)
                if (part ~ /^kind=/) {
                    pipe_kind = substr(part, 6)
                    if (pipe_kind == "safe-auto-fix") {
                        pipe_kind = "safe_auto_fix"
                    }
                }
                if (part ~ /^severity=/) {
                    pipe_severity = substr(part, 10)
                }
            }
            if (pipe_kind != "") {
                emit_entry()
                kind = pipe_kind
                severity = pipe_severity
                emit_entry()
            }
        }
        END { emit_entry() }
    ' "$tmp" | jq -Rsc '
        split("\n")
        | map(select(length > 0) | split("\t") | {kind: .[0], severity: (.[1] // "")})
    '
    rm -f "$tmp"
}
