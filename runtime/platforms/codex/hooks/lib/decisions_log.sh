#!/usr/bin/env bash
# Shared parser for `.sage/decisions.md` entry boundaries.

decisions_entry_count() {
    local file="$1"
    [ -f "$file" ] || {
        printf '0\n'
        return 0
    }
    awk '
        /^### [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]/ { count++; next }
        /^- \[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\] / { count++; next }
        END { print count + 0 }
    ' "$file" 2>/dev/null || printf '0\n'
}

decisions_entry_line_at() {
    local file="$1"
    local target="$2"
    [ -f "$file" ] || return 0
    case "$target" in ''|*[!0-9]*) return 0 ;; esac
    awk -v target="$target" '
        /^### [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]/ { count++; if (count == target) { print NR; exit } }
        /^- \[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\] / { count++; if (count == target) { print NR; exit } }
    ' "$file" 2>/dev/null || true
}

decisions_recent_tsv() {
    local file="$1"
    local limit="${2:-3}"
    [ -f "$file" ] || return 0
    case "$limit" in ''|*[!0-9]*) limit=3 ;; esac
    awk -v limit="$limit" '
        function is_entry(line) {
            return line ~ /^### [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]/ ||
                   line ~ /^- \[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\] /
        }
        function entry_date(line) {
            if (line ~ /^### /) {
                return substr(line, 5, 10)
            }
            return substr(line, 4, 10)
        }
        function entry_title(line, title) {
            title = line
            if (title ~ /^### /) {
                sub(/^### [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]+(—|-)[[:space:]]*/, "", title)
            } else {
                sub(/^- \[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\][[:space:]]*/, "", title)
            }
            return title
        }
        function flush() {
            if (!in_entry || emitted >= limit) {
                return
            }
            gsub(/\t/, " ", title)
            gsub(/\t/, " ", body)
            printf "%s\t%s\t%s\n", date, title, body
            emitted++
        }
        is_entry($0) {
            flush()
            if (emitted >= limit) {
                exit
            }
            in_entry = 1
            date = entry_date($0)
            title = entry_title($0)
            body = ""
            body_lines = 0
            next
        }
        in_entry && body_lines < 3 && $0 !~ /^[[:space:]]*$/ {
            if (body != "") {
                body = body "\\n"
            }
            body = body $0
            body_lines++
        }
        END { flush() }
    ' "$file" 2>/dev/null || true
}

decisions_recent_json() {
    local file="$1"
    local limit="${2:-3}"
    local decisions_json=""
    local date_str title_str body_str entry
    while IFS="$(printf '\t')" read -r date_str title_str body_str; do
        [ -n "$date_str" ] || continue
        entry="$(jq -n --arg date "$date_str" --arg title "$title_str" --arg body "$body_str" \
            '{date: $date, title: $title, body: $body}')" || continue
        [ -z "$decisions_json" ] && decisions_json="$entry" || decisions_json="${decisions_json},${entry}"
    done < <(decisions_recent_tsv "$file" "$limit")
    printf '[%s]\n' "$decisions_json"
}

decisions_recent_labels() {
    local file="$1"
    local limit="${2:-3}"
    local date_str title_str body_str
    while IFS="$(printf '\t')" read -r date_str title_str body_str; do
        [ -n "$date_str" ] || continue
        printf '  - %s — %s\n' "$date_str" "$title_str"
    done < <(decisions_recent_tsv "$file" "$limit")
}
