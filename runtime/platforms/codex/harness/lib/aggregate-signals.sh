#!/usr/bin/env bash
# aggregate-signals.sh — collect §13.2 v2-promotion-trigger signals
# from a single harness run.
#
# Inputs (positional):
#   $1 — TARGET dir (where bin/sage init was run)
#   $2 — TRANSCRIPTS dir (one .jsonl per prompt — codex exec --json output)
#   $3 — FRAMEWORK_ROOT (sage-selfhost root, for predicate LOC measurement)
#
# Output: JSON document on stdout, one object with all 8 signal blocks.
#   Plan T2.7 contract: 7-of-8 wired, signal 5 (bash-mediated mutation
#   leaks) + signal 6b (p95 latency) STUB-WITH-TODO per plan §13.2
#   anti-gap rule. Cost > 1 day for v1; declared up-front, not silent.
#
# v1 plan ref: T2.7 (M2 Group).
# Spec ref: §13.2 outcome-harness signals.

set -euo pipefail

TARGET="${1:?target dir required}"
TRANSCRIPTS="${2:?transcripts dir required}"
FRAMEWORK_ROOT="${3:?framework root required}"

incidents_log="$TARGET/.sage/.mcp-incidents.log"
session_mut_log="$TARGET/.sage/.session-mutations.log"
scenario_manifest="$FRAMEWORK_ROOT/runtime/platforms/codex/harness/v11-scenarios.json"
first_state="$(find "$TRANSCRIPTS" -maxdepth 1 -type f -name '*.state.json' | sort | head -1)"
report_model="unknown"
report_reasoning="unknown"
report_target_mode="unknown"
report_run_mode="full"
report_hook_mode="unknown"
report_service_tier="default"
if [ -n "$first_state" ] && [ -f "$first_state" ]; then
    report_model="$(jq -r '.model // "unknown"' "$first_state" 2>/dev/null || echo unknown)"
    report_reasoning="$(jq -r '.reasoning_effort // "unknown"' "$first_state" 2>/dev/null || echo unknown)"
    report_target_mode="$(jq -r '.target_mode // "unknown"' "$first_state" 2>/dev/null || echo unknown)"
    report_run_mode="$(jq -r '.run_mode // "full"' "$first_state" 2>/dev/null || echo full)"
    report_hook_mode="$(jq -r '.hook_mode // "unknown"' "$first_state" 2>/dev/null || echo unknown)"
    report_service_tier="$(jq -r '.service_tier // "default"' "$first_state" 2>/dev/null || echo default)"
fi
if [ -n "${HARNESS_SCENARIOS:-}" ]; then
    report_run_mode="targeted"
fi
report_prompts_json="$(
    while IFS= read -r state_file; do
        [ -n "$state_file" ] || continue
        jq -r '.prompt // empty' "$state_file" 2>/dev/null || true
    done < <(find "$TRANSCRIPTS" -maxdepth 1 -type f -name '*.state.json' | sort) |
        jq -R . | jq -sc .
)"

regex_escape() {
    sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

expand_rubric_pattern() {
    local pattern="$1"
    local escaped_framework
    escaped_framework="$(printf '%s' "$FRAMEWORK_ROOT" | regex_escape)"
    printf '%s' "${pattern//__FRAMEWORK_ROOT__/$escaped_framework}"
}

matches_scenario_filter() {
    local id="${1:?scenario id required}"
    local prompt="${2:?scenario prompt required}"
    local base="${prompt%.txt}"
    local token

    [ -n "${HARNESS_SCENARIOS:-}" ] || return 0
    while IFS= read -r token; do
        [ -n "$token" ] || continue
        if [ "$token" = "$id" ] || [ "$token" = "$prompt" ] || [ "$token" = "$base" ]; then
            return 0
        fi
    done < <(printf '%s\n' "$HARNESS_SCENARIOS" | tr ',' '\n' | tr '[:space:]' '\n')
    return 1
}

# --- Signal 1: workflow-entry rate ----------------------------------
# Count `/sage:` (or `/sage`) invocations in agent transcripts. Each
# transcript is a JSON-lines stream from `codex exec --json`; the agent's
# textual output contains slash-commands as plain text.
signal1_count=0
signal1_total_prompts=0
for f in "$TRANSCRIPTS"/*.jsonl; do
    [ -f "$f" ] || continue
    signal1_total_prompts=$((signal1_total_prompts + 1))
    if grep -E -q '/sage(:[a-z-]+)?\b' "$f" 2>/dev/null; then
        signal1_count=$((signal1_count + 1))
    fi
done

# --- Signal 2: phase_jump_observed rate -----------------------------
# `grep -c` exits 1 when zero matches; capture both branches cleanly.
signal2_count=0
if [ -f "$incidents_log" ]; then
    signal2_count="$(grep -c '"kind":"phase_jump_observed"' "$incidents_log" 2>/dev/null || true)"
    signal2_count="${signal2_count:-0}"
fi

# --- Signal 3: bypass_mutation rate ---------------------------------
signal3_count=0
if [ -f "$incidents_log" ]; then
    signal3_count="$(grep -c '"kind":"bypass_mutation"' "$incidents_log" 2>/dev/null || true)"
    signal3_count="${signal3_count:-0}"
fi

# --- Signal 4: doctor S1 incidents ----------------------------------
# Run `bin/sage doctor` against target; count S1 lines that fail.
# `bin/sage doctor` v1 emits text; we grep for "S1" + non-ok status.
signal4_count=0
if [ -x "$FRAMEWORK_ROOT/bin/sage" ]; then
    doctor_out="$( (cd "$TARGET" && "$FRAMEWORK_ROOT/bin/sage" doctor 2>&1) || true )"
    signal4_count="$(printf '%s' "$doctor_out" | grep -cE '^\s*✗.*S1' || true)"
    signal4_count="${signal4_count:-0}"
fi

# --- Signal 5: bash-mediated mutation leaks (STUB) ------------------
# Plan T2.7 §13.2 contract: stub-with-TODO permitted if instrumentation
# cost > 1 day. Detection requires JSON-parsing every codex transcript
# for `bash` tool calls AND correlating the command's write target
# against the cycle's scope: globs. Real implementation needs:
#   - jq pipeline over each transcript event with .type=="exec_command"
#   - parse cmd argv, extract redirect targets (`>`, `>>`) + sed -i path
#   - cross-reference scope: from manifest.md
# v1.x or v2 work. Currently emits TODO marker, not silent zero.
signal5_status="TODO"
signal5_note="Bash-tool transcript scan not yet implemented (cost > 1 day for v1 seed; see plan T2.7 anti-gap rule). bypass_mutation incident covers untracked-write detection ex post via Stop hook (signal 3); bash-time prevention is the v2 ADR-1 v2 trigger."

# --- Signal 6a: predicate LOC drift ---------------------------------
predicate_path="$FRAMEWORK_ROOT/runtime/platforms/codex/hooks/pre-tool-validate.sh"
signal6a_loc=0
if [ -f "$predicate_path" ]; then
    signal6a_loc="$(wc -l < "$predicate_path" | tr -d ' ')"
fi
signal6a_ceiling=160 # calibrated v1.1 ceiling after semantic
                     # reclassification + parked-cycle protections; still
                     # below the ~200-LOC v2-promotion threshold from spec §8.

# --- Signal 6b: predicate p95 latency drift (STUB) ------------------
# Hooks do not currently emit per-invocation duration_ms — plan
# T2.7 §13.2 stub-with-TODO. Adding timing requires patch to
# pre-tool-validate.sh + a timing log file (.sage/.hook-timings.log)
# read by aggregate. Defer to v1.x or v2; declared explicitly.
signal6b_status="TODO"
signal6b_note="Per-invocation duration_ms not currently logged by pre-tool-validate.sh. Adding requires hook patch + timing log + p95 calculator (~1 day). Spec §6.3 v2 promotion trigger #1 (cold-start latency > 1s) cannot fire from this seed yet."

# --- Signal 7: L1-bypass detection ----------------------------------
# Prefer state snapshots from this harness run. The harness commits each
# session after capture, so git-only commit correlation is noisy here; state
# incidents are the authoritative run evidence when present. Keep the old
# commit proxy as fallback for legacy reports without state snapshots.
signal7_count=0
signal7_total_commits=0
state_snapshot_count="$(find "$TRANSCRIPTS" -maxdepth 1 -type f -name '*.state.json' | wc -l | tr -d ' ')"
if [ "${state_snapshot_count:-0}" -gt 0 ]; then
    while IFS= read -r state_file; do
        [ -n "$state_file" ] || continue
        signal7_total_commits=$((signal7_total_commits + 1))
        if jq -e '.incidents[]? | select(.kind == "bypass_mutation")' "$state_file" >/dev/null; then
            signal7_count=$((signal7_count + 1))
        fi
    done < <(find "$TRANSCRIPTS" -maxdepth 1 -type f -name '*.state.json' | sort)
elif [ -d "$TARGET/.git" ]; then
    cd "$TARGET" || exit 0
    while IFS= read -r commit; do
        [ -n "$commit" ] || continue
        subject="$(git log -1 --format=%s "$commit" 2>/dev/null || true)"
        case "$subject" in
            seed|"sage init:"*) continue ;;
        esac
        signal7_total_commits=$((signal7_total_commits + 1))
        # Files changed in this commit (parent diff; first commit gets full tree)
        if git rev-parse "$commit"^ >/dev/null 2>&1; then
            files="$(git diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null || true)"
        else
            files="$(git ls-tree -r --name-only "$commit" 2>/dev/null || true)"
        fi
        # Skip if no files (merge commits, etc.)
        [ -n "$files" ] || continue
        # Did session-mutations.log capture any of these files?
        bypassed=1
        if [ -f "$session_mut_log" ]; then
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                if grep -F -q "\"$f\"" "$session_mut_log" 2>/dev/null; then
                    bypassed=0
                    break
                fi
            done <<< "$files"
        fi
        [ "$bypassed" = "1" ] && signal7_count=$((signal7_count + 1))
    done < <(git log --format='%H' 2>/dev/null || true)
    cd - >/dev/null
fi

# --- Signal 8: decisions-missing-after-required-scenario -------------
# Signal 8 is metadata-driven, not a natural-language classifier. A scenario
# counts only when v11-scenarios.json explicitly sets
# `requires_decision_entry: true`. Missing/false means process-only,
# frontmatter-only, or bookkeeping and is not penalized for omitting a global
# decisions entry.
signal8_count=0
signal8_total_flips=0
if [ -f "$scenario_manifest" ]; then
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        scenario_id="$(printf '%s' "$row" | jq -r '.id // ""')"
        prompt="$(printf '%s' "$row" | jq -r '.prompt')"
        matches_scenario_filter "$scenario_id" "$prompt" || continue
        requires_decision_entry="$(printf '%s' "$row" | jq -r '.requires_decision_entry // false')"
        [ "$requires_decision_entry" = "true" ] || continue
        signal8_total_flips=$((signal8_total_flips + 1))
        state_file="$TRANSCRIPTS/${prompt%.txt}.jsonl.state.json"
        if [ ! -f "$state_file" ] || ! jq -e '.changed_files[]? | select(. == ".sage/decisions.md")' "$state_file" >/dev/null; then
            signal8_count=$((signal8_count + 1))
        fi
    done < <(jq -c '.scenarios[]' "$scenario_manifest")
fi

# --- v1.1 verification contract -------------------------------------
# Deterministic Bats proves framework outputs and hook predicates. These
# release-blocker scenarios require real `codex exec --json` transcripts,
# because they are claims about agent/runtime behavior.
v11_total_release_blockers=0
v11_present_release_blockers=0
v11_missing_release_blockers_json='[]'
v11_scenarios_json='[]'
v11_release_rule="v1.1 cannot be marked complete unless deterministic tests pass and every release_blocker scenario has a real Codex transcript from the current harness run with codex exec exit code 0."
if [ -f "$scenario_manifest" ]; then
    if [ -n "${HARNESS_SCENARIOS:-}" ]; then
        v11_scenarios_json="$(jq -c --arg filter "$HARNESS_SCENARIOS" '
            ($filter | gsub("[,[:space:]]+"; " ") | split(" ") | map(select(length > 0))) as $tokens
            | [.scenarios[] | . as $scenario | select(
                ($tokens | index($scenario.id))
                or ($tokens | index($scenario.prompt))
                or ($tokens | index($scenario.prompt | sub("\\.txt$"; "")))
            )]
        ' "$scenario_manifest")"
    else
        v11_scenarios_json="$(jq -c '.scenarios' "$scenario_manifest")"
    fi
    v11_release_rule="$(jq -r '.policy.release_rule // empty' "$scenario_manifest")"
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        scenario_id="$(printf '%s' "$row" | jq -r '.id // ""')"
        prompt="$(printf '%s' "$row" | jq -r '.prompt')"
        matches_scenario_filter "$scenario_id" "$prompt" || continue
        is_blocker="$(printf '%s' "$row" | jq -r '.release_blocker // false')"
        [ "$is_blocker" = "true" ] || continue
        v11_total_release_blockers=$((v11_total_release_blockers + 1))
        base="$TRANSCRIPTS/${prompt%.txt}.jsonl"
        transcript="$base"
        exit_file="$base.exit"
        exit_code="missing"
        [ -f "$exit_file" ] && exit_code="$(cat "$exit_file" 2>/dev/null || echo missing)"
        state_file="$base.state.json"
        rubric_failures='[]'
        rubric_pass=true
        rubric="$(printf '%s' "$row" | jq -c '.state_rubric // {}')"
        rubric_required_count="$(jq '[.expected_files[]?, .forbidden_files[]?, .forbidden_changed_patterns[]?, .forbidden_audit_kinds[]?, .required_audit_kinds[]?, .required_transcript_patterns[]?, .forbidden_transcript_patterns[]?, .required_changed_patterns[]?, .required_new_manifest_patterns[]?, .expected_secondary_files[]?, .required_secondary_changed_patterns[]?, .forbidden_secondary_changed_patterns[]?] | length' <<< "$rubric")"
        claim="$(printf '%s' "$row" | jq -r '.claim // ""')"
        if [ "$rubric_required_count" -eq 0 ] && printf '%s' "$claim" | grep -Eiq 'blocked mutation|blocked|recovery'; then
            rubric_pass=false
            rubric_failures="$(jq -c --arg msg "empty rubric for blocked/recovery release blocker" '. + [$msg]' <<< "$rubric_failures")"
        fi
        if [ ! -f "$state_file" ] && [ "$rubric_required_count" -gt 0 ]; then
            rubric_pass=false
            rubric_failures="$(jq -c --arg msg "missing state snapshot: $state_file" '. + [$msg]' <<< "$rubric_failures")"
        fi
        if [ -f "$state_file" ]; then
            while IFS= read -r expected; do
                [ -n "$expected" ] || continue
                if ! jq -e --arg p "$expected" '.files | index($p)' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing expected file: $expected" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.expected_files[]? // empty' <<< "$rubric")
            while IFS= read -r forbidden; do
                [ -n "$forbidden" ] || continue
                if jq -e --arg p "$forbidden" '.files | index($p)' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "forbidden file present: $forbidden" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.forbidden_files[]? // empty' <<< "$rubric")
            while IFS= read -r kind; do
                [ -n "$kind" ] || continue
                if ! jq -e --arg kind "$kind" '(.incidents[]?, .auto_fixes[]?) | select(.kind == $kind)' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing audit kind: $kind" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.required_audit_kinds[]? // empty' <<< "$rubric")
            while IFS= read -r kind; do
                [ -n "$kind" ] || continue
                if jq -e --arg kind "$kind" '(.incidents[]?, .auto_fixes[]?) | select(.kind == $kind)' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "forbidden audit kind present: $kind" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.forbidden_audit_kinds[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if ! jq -e --arg pattern "$pattern" '.changed_files[]? | select(test($pattern))' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing changed file pattern: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.required_changed_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if jq -e --arg pattern "$pattern" '.changed_files[]? | select(test($pattern))' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "forbidden changed file pattern present: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.forbidden_changed_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if ! jq -e --arg pattern "$pattern" '.new_manifests[]? | select(test($pattern))' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing new manifest pattern: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.required_new_manifest_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r expected; do
                [ -n "$expected" ] || continue
                if ! jq -e --arg p "$expected" '(.secondary_files // []) | index($p)' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing expected secondary file: $expected" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.expected_secondary_files[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if ! jq -e --arg pattern "$pattern" '(.secondary_changed_files // [])[]? | select(test($pattern))' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing secondary changed file pattern: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.required_secondary_changed_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if jq -e --arg pattern "$pattern" '(.secondary_changed_files // [])[]? | select(test($pattern))' "$state_file" >/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "forbidden secondary changed file pattern present: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.forbidden_secondary_changed_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                if ! grep -E -q "$pattern" "$transcript" 2>/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "missing transcript pattern: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.required_transcript_patterns[]? // empty' <<< "$rubric")
            while IFS= read -r pattern; do
                [ -n "$pattern" ] || continue
                expanded_pattern="$(expand_rubric_pattern "$pattern")"
                if [ -s "$transcript" ] && grep -E -q "$expanded_pattern" "$transcript" 2>/dev/null; then
                    rubric_pass=false
                    rubric_failures="$(jq -c --arg msg "forbidden transcript pattern present: $pattern" '. + [$msg]' <<< "$rubric_failures")"
                fi
            done < <(jq -r '.forbidden_transcript_patterns[]? // empty' <<< "$rubric")
        fi
        if [ -s "$transcript" ] && [ "$exit_code" = "0" ] && [ "$rubric_pass" = "true" ]; then
            v11_present_release_blockers=$((v11_present_release_blockers + 1))
        else
            missing_item="$(printf '%s' "$row" | jq -c --arg transcript "$transcript" --arg exit_code "$exit_code" --arg state_file "$state_file" --argjson rubric_failures "$rubric_failures" '. + {missing_transcript:$transcript, exit_code:$exit_code, state_file:$state_file, rubric_failures:$rubric_failures}')"
            v11_missing_release_blockers_json="$(jq -c --argjson item "$missing_item" '. + [$item]' <<< "$v11_missing_release_blockers_json")"
        fi
    done < <(jq -c '.scenarios[]' "$scenario_manifest")
fi

# --- Emit aggregate JSON --------------------------------------------
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
codex_version="$(codex --version 2>/dev/null | head -1 || echo unknown)"

jq -n \
    --arg ts "$ts" \
    --arg codex_version "$codex_version" \
    --arg target "$TARGET" \
    --arg model "$report_model" \
    --arg reasoning "$report_reasoning" \
    --arg target_mode "$report_target_mode" \
    --arg run_mode "$report_run_mode" \
    --arg hook_mode "$report_hook_mode" \
    --arg service_tier "$report_service_tier" \
    --argjson prompts "$report_prompts_json" \
    --argjson s1_count "$signal1_count" \
    --argjson s1_total "$signal1_total_prompts" \
    --argjson s2_count "$signal2_count" \
    --argjson s3_count "$signal3_count" \
    --argjson s4_count "$signal4_count" \
    --arg s5_status "$signal5_status" \
    --arg s5_note "$signal5_note" \
    --argjson s6a_loc "$signal6a_loc" \
    --argjson s6a_ceiling "$signal6a_ceiling" \
    --arg s6b_status "$signal6b_status" \
    --arg s6b_note "$signal6b_note" \
    --argjson s7_count "$signal7_count" \
    --argjson s7_total "$signal7_total_commits" \
    --argjson s8_count "$signal8_count" \
    --argjson s8_total "$signal8_total_flips" \
    --argjson v11_total "$v11_total_release_blockers" \
    --argjson v11_present "$v11_present_release_blockers" \
    --argjson v11_missing "$v11_missing_release_blockers_json" \
    --argjson v11_scenarios "$v11_scenarios_json" \
    --arg v11_release_rule "$v11_release_rule" \
    '{
        ts: $ts,
        codex_version: $codex_version,
        target: $target,
        model_profile: {
            model: $model,
            reasoning_effort: $reasoning,
            target_mode: $target_mode,
            run_mode: $run_mode,
            hook_mode: $hook_mode,
            service_tier: $service_tier,
            forbidden_models: ["gpt-5.5"]
        },
        harness_run: {
            run_mode: $run_mode,
            hook_mode: $hook_mode,
            service_tier: $service_tier,
            prompts: $prompts
        },
        signals: {
            "1_workflow_entry": {
                description: "Sage workflow-entry rate (prompts that invoked /sage:* slash command)",
                count: $s1_count,
                total: $s1_total,
                rate: (if $s1_total > 0 then ($s1_count / $s1_total) else 0 end)
            },
            "2_phase_jump": {
                description: "phase_jump_observed incidents (turn-audit Stop hook detection)",
                count: $s2_count
            },
            "3_bypass_mutation": {
                description: "bypass_mutation incidents (turn-audit detected unclaimed git diff)",
                count: $s3_count
            },
            "4_doctor_s1": {
                description: "S1 doctor check failures after harness run",
                count: $s4_count
            },
            "5_bash_mutation_leaks": {
                description: "Agent bash-tool writes to managed paths bypassing apply_patch (per spec §13.2)",
                status: $s5_status,
                note: $s5_note
            },
            "6a_predicate_loc": {
                description: "pre-tool-validate.sh line count vs calibrated v1.1 ceiling",
                loc: $s6a_loc,
                ceiling: $s6a_ceiling,
                over_ceiling: ($s6a_loc > $s6a_ceiling)
            },
            "6b_predicate_p95_latency_ms": {
                description: "pre-tool-validate.sh p95 invocation latency (cold-start drift signal)",
                status: $s6b_status,
                note: $s6b_note
            },
            "7_l1_bypass": {
                description: "Harness state snapshots with bypass_mutation incidents; falls back to commit/log correlation for legacy reports",
                count: $s7_count,
                total: $s7_total,
                rate: (if $s7_total > 0 then ($s7_count / $s7_total) else 0 end)
            },
            "8_decisions_missing": {
                description: "requires_decision_entry scenarios without .sage/decisions.md in changed_files",
                count: $s8_count,
                total: $s8_total,
                rate: (if $s8_total > 0 then ($s8_count / $s8_total) else 0 end)
            },
            "v11_release_blocker_harness": {
                description: "Codex operating model v1.1 release-blocker scenarios with real transcript evidence",
                deterministic_required_for: [
                    "generated instructions",
                    "hook predicates",
                    "status/doctor output",
                    "artifact routing text",
                    "audit log schemas"
                ],
                real_harness_required_for: [
                    "agent workflow routing",
                    "agent recovery behavior",
                    "agent capture behavior",
                    "memory reuse across sessions",
                    "cross-repo state ownership"
                ],
                total: $v11_total,
                present: $v11_present,
                missing: $v11_missing,
                run_mode: $run_mode,
                complete: ($run_mode == "full" and $v11_total > 0 and $v11_present == $v11_total),
                release_rule: $v11_release_rule,
                scenarios: $v11_scenarios
            }
        }
    }'
