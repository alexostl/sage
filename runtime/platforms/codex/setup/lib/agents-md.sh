#!/usr/bin/env bash
# shellcheck disable=SC2001
# agents-md.sh — Stage 3 composer for `<target>/AGENTS.md`.
# (SC2001 disabled: `sed 's/^[0-9]*\.//'` is the clearest expression of
# "strip leading numbering"; bash param-expansion equivalent is ugly.)
#
# Responsibilities:
#   1. Detect Rule 1A variant (mcp vs filesystem) from .codex/config.toml.
#   2. Resolve effective preset from --preset and .sage/constitution.md
#      extends: field (user overlay wins).
#   3. Build merged constitution (base + preset overlay + user additions).
#   4. Render template body with __CONSTITUTION_PLACEHOLDER__ substitution.
#   5. Apply prefix-managed write (preserve content below SAGE-MANAGED-END;
#      backup + regenerate if marker absent and file present).
#
# Entry point: compose_agents_md <target> <preset> <sage_framework>
#
# v1 spec ref: §4 Stage 3 (B1 Rule 1A variant + B3 user overlay).
# v1 plan ref: T1.11.

# ------------------------------------------------------------------
# Rule 1A variant detection (B1)
# ------------------------------------------------------------------

_detect_rule_1a_variant() {
    local target="$1"
    local cfg="$target/.codex/config.toml"
    if [ -f "$cfg" ] && grep -qE '^\[\[mcp_servers\]\]' "$cfg" 2>/dev/null; then
        echo "mcp"
    else
        echo "filesystem"
    fi
}

# ------------------------------------------------------------------
# Effective preset resolution (B3 user overlay)
# ------------------------------------------------------------------

_resolve_effective_preset() {
    local target="$1"
    local cli_preset="$2"
    local user_const="$target/.sage/constitution.md"
    local user_extends=""
    if [ -f "$user_const" ]; then
        user_extends="$(awk '/^---$/{c++; next} c==1 && /^extends:/{sub(/^extends:[[:space:]]*/,""); print; exit} c>=2{exit}' "$user_const" 2>/dev/null | tr -d '[:space:]')"
    fi
    if [ -n "$user_extends" ]; then
        echo "$user_extends"
    else
        echo "$cli_preset"
    fi
}

# ------------------------------------------------------------------
# Constitution section composer (3-layer merge)
# ------------------------------------------------------------------

_compose_constitution_section() {
    local effective_preset="$1"
    local sage_framework="$2"
    local target="$3"

    local base_section
    base_section="## Engineering Principles

Base (all projects):
1. Tests before code — every behavior has a test before implementation
2. No silent failures — errors handled, logged, or propagated
3. Secrets never in code — use env vars or secret managers
   Agent must not write, echo, quote, log, or suggest commands containing real
   secret values; use redacted placeholders and ask the user to enter values
   manually.
4. Dependencies explicit — declared with pinned versions
5. Changes reversible — migrations reversible, deployments rollbackable"

    local principle_num=5
    local out="$base_section"

    # Layer 2 — preset overlay (sentinel-bypass per T1.9).
    case "$effective_preset" in
        base|none|"")
            : # sentinel — base alone is sufficient, no warning
            ;;
        *)
            local preset_file="$sage_framework/core/constitution/presets/${effective_preset}.constitution.md"
            if [ -f "$preset_file" ]; then
                local preset_lines
                preset_lines="$(sed -n '/^## Additions/,$ { /^[0-9]/p; }' "$preset_file")"
                if [ -n "$preset_lines" ]; then
                    out="$out

${effective_preset} preset:"
                    while IFS= read -r line; do
                        [ -n "$line" ] || continue
                        principle_num=$((principle_num + 1))
                        # Strip leading "<num>. " from upstream numbering.
                        # shellcheck disable=SC2001
                        local clean
                        clean="$(echo "$line" | sed 's/^[0-9]*\.[[:space:]]*//')"
                        out="$out
${principle_num}. ${clean}"
                    done <<< "$preset_lines"
                fi
            else
                printf 'generate-codex: Preset overlay missing: %s — falling back to base layer\n' \
                    "$effective_preset" >&2
            fi
            ;;
    esac

    # Layer 3 — user overlay project additions.
    local user_const="$target/.sage/constitution.md"
    if [ -f "$user_const" ]; then
        local additions
        additions="$(sed -n '/^## Project Additions/,$ { /^## Project Additions/d; /^[[:space:]]*$/d; p; }' "$user_const" 2>/dev/null)"
        if [ -n "$additions" ]; then
            out="$out

Project additions:"
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                principle_num=$((principle_num + 1))
                # shellcheck disable=SC2001
                local clean
                clean="$(echo "$line" | sed 's/^[0-9]*\.[[:space:]]*//')"
                out="$out
${principle_num}. ${clean}"
            done <<< "$additions"
        fi
    fi

    printf '%s\n' "$out"
}

# ------------------------------------------------------------------
# Rule 1A renderer (variant-aware)
# ------------------------------------------------------------------

_render_rule_1a() {
    local variant="$1"
    if [ "$variant" = "mcp" ]; then
        cat <<'EOF'
### Rule 1A — Targeted Recall Before Work

Before Standard+ work, decide whether durable project context may matter:
1. Discover available Sage Memory tools through the available Codex
   tool-discovery surface. In Codex Desktop this may be \`tool_search\`; in
   CLI/app-server contexts use the available MCP status/tool surfaces or
   configured MCP tools.
2. Activate/select the current project before any SageMemory operation.
3. Use targeted project/domain recall only when decisions, entities,
   preferences, prior corrections, or project history could affect the work.
4. For correction-sensitive work, search self-learning with
   \`filter_tags: ["self-learning"]\`.
5. Fall back to `.sage-memory/` files only when MCP tools are unavailable.

Do not run broad \`sage_memory_search\` as a session-start preload.

Sage Memory is the project/correction store. Codex built-in Memories are a
separate platform feature and are not the Sage workflow state backend.
EOF
    else
        cat <<'EOF'
### Rule 1A — Targeted Recall Before Work

Before Standard+ work, decide whether durable project context may matter:
1. Discover available Sage Memory tools through the available Codex
   tool-discovery surface. In Codex Desktop this may be \`tool_search\`; in
   CLI/app-server contexts use the available MCP status/tool surfaces or
   configured MCP tools.
2. Activate/select the current project before any SageMemory operation.
3. Use targeted project/domain recall only when decisions, entities,
   preferences, prior corrections, or project history could affect the work.
4. For correction-sensitive work, search self-learning with
   \`filter_tags: ["self-learning"]\`.
5. Fall back to `.sage-memory/` files only when MCP tools are unavailable.

Do not run broad \`sage_memory_search\` as a session-start preload.

Sage Memory is the project/correction store. Codex built-in Memories are a
separate platform feature and are not the Sage workflow state backend.
EOF
    fi
}

# ------------------------------------------------------------------
# Sage prefix body (everything above SAGE-MANAGED-END marker)
# ------------------------------------------------------------------

_build_sage_prefix() {
    local effective_preset="$1"
    local sage_framework="$2"
    local target="$3"
    local rule_1a_variant="$4"

    local const_section
    const_section="$(_compose_constitution_section "$effective_preset" "$sage_framework" "$target")"

    local rule_1a_block
    rule_1a_block="$(_render_rule_1a "$rule_1a_variant")"

    cat <<EOF
# Sage — Project Instructions

> Auto-generated by Sage. Regenerate with \`bin/sage update\`.
> Content below \`<!-- SAGE-MANAGED-END -->\` is yours, edit freely.

## Operating Kernel

These rules are the always-loaded Sage contract for Codex. Keep details in
\`.agents/skills/*\` and \`core/workflows/*\`; this file is the router.

${rule_1a_block}

### Route Work, Preserve Conversation

Before doing Standard+ work, route to the right Sage workflow. Conversation
is not work by itself: conversational/read-only questions can be answered
without workflow by default.

Classify the user's mandate:
- conversational/read-only question → answer conversationally by default;
  do not announce a workflow or write artifacts
- explicit workflow command (\`\$sage:build\`, \`\$sage:fix\`, etc.) → enter that
  workflow and follow its gates
- action mandate, including polite question-form mandates like "Can you fix
  this?", "Could you implement this?", or "Would you run a smoke test?" →
  route to workflow or confirmation
- bug report/finding/observation without an explicit fix mandate → capture or
  diagnose first; do not edit code until the user explicitly asks for a fix or
  a workflow gate approves implementation
- ambiguous/borderline prompt → use soft confirmation before workflow

When active work exists, acknowledge it when relevant, but unrelated
read-only questions may be answered from context without resuming
implementation. After workflow entry, Codex-native enforcement still applies:
spec/plan gates, fix root-cause approval, lifecycle mutation protection, and
verification-before-done remain mandatory.

Standard+ fixes must update plan.md and manifest.md before code changes.
Writing plan.md or manifest.md after code does not cure the violation.

State transitions are part of the contract:
- Lightweight work may finish with code plus conversation summary; do
  not create \`.sage\` records unless there is a durable decision, follow-up,
  learning, incident/recovery, or active-cycle mutation.
- Standard+ entry or resume must create/update the manifest before
  artifacts or code. After changing \`status\` or \`phase\`, say what changed.
- Use this order: identify workflow/cycle, update \`manifest.md\` first,
  announce the completed state change, then write artifacts/code.
- Fix-trigger prompts in instruction/process files require \`/fix\` diagnosis and scope
  before mutation, even for typos; obvious non-canonical typos stay Tier 1 only
  outside instruction/process surfaces.
- recoverable hook block is correction guidance: retry via legal path/stop for user decision
- Mutation preflight before write: active cycle/status/count; threshold/closeout/tool path. Text edits use \`apply_patch\`; binary assets need explicit binary path and implementation state.
- Lightweight direct-edit mode is quantitative: exactly 1 file, at most 2 diff lines total,
  no manifest, and no secrets/policy/runtime/instruction surfaces.
- Before mutation, choose the legal mode: read-only, surgical, capture, workflow, or closed-cycle-bookkeeping. If there is no valid mode, a mode mismatch, paused/closed/wrong-cycle state, cross-repo ambiguity, or prior hook block, activate Sage Navigator/workflow docs before editing; paused means route/recover, not wait.
- Closeout order: completion checkpoint is not approval; keep manifest active until user approves closeout; then set cycle manifest \`status: closed\` and \`phase: closed\` last after self-review/artifacts/decisions/handoff; artifact frontmatter may still use \`status: completed\`; report stage/commit, ask handoff, no default push, no post-closeout .sage epilogue. Standalone closeout.md is exceptional: reserve it for umbrella/milestone/multi-phase/architecture cycles, not ordinary non-milestone work.

For Standard+ Codex work, keep native plan/progress view as visibility layer;
never replaces Sage artifacts. Skip for lightweight/read-only conversation.

### Alex-native operating contract

Sage structure, keys, commands, paths, code ids, quoted evidence, and canonical
terms stay in English. Treść prozatorską nowych sekcji w \`.sage\` pisz po
polsku — także wtedy, gdy dopisujesz do starszego angielskiego pliku. Treat Alex
as Junior Dev Vibecoder: explain bugs/findings first as impact and cause, then
name the technical mechanism; use: co się dzieje → czemu to problem → jak to się technicznie nazywa → co trzeba zmienić. Ask jedno pytanie naraz; add 1-3 klikalne linki at checkpoints.
At real option gates, mark one option as \`(Recommended)\` and add \`Rekomenduję [A], bo ...\`; this is advice, not approval.

After an approved plan checkpoint, preserve two implementation paths:
\`[C] Checkpointed implementation\` and \`[F] Full autonomous implementation\`.
The full autonomous path is scoped autonomy, not general autonomy: execute the
approved plan without intermediate checkpoints until verification/close, bound
to the approved plan and workflow stop conditions. Any scope expansion cancels the grant;
so does a new workflow/follow-up, product/architecture decision, key assumption,
conflict, or material risk changes the plan.
Before either path mutates runtime/source/test files, write a manifest-only readiness patch: set \`status: implementing\` and bind the real runtime \`active_session_id\` when the platform exposes one. \`active_session_id\` is an
implementation/control lock, not a planning requirement; never infer it from
\`codex://threads/*\`, \`CODEX_THREAD_ID\`, transcripts, logs, or an analyzed
thread id.

\`[I] Revise and Implement in the same turn\` is explicit bounded conditional
approval: apply only the user-specified revision and continue only when the
revision stays inside the approved plan/checkpoint evidence. It is never
self-approval.

When using subagents/reviewer agents, give project instructions, Sage scope, and
MCP/tool expectations. Subagent edits are not exempt from lifecycle state, plan
approval, or verification gates.
Alex-facing subagent handoff prompts use Polish natural-language prose;
canonical identifiers stay verbatim.

Codex subagent authorization must be literal. Only call spawn_agent after the
user asks for subagents/delegation/parallel work, or selects [A] Subagent
review for a read-only subagent. "review please" is not enough; ask for subagent review vs self-review.

### State First

Before any substantial response, scan \`.sage/work/\` frontmatter for
active initiatives. Read \`.sage/decisions.md\` for recent context.
Never start fresh when there is existing context.

Treat \`status: defining\` and legacy \`status: in-progress\` as live workflow
definition state, including active approval checkpoints such as
\`root-cause-gate\`, \`fix-scope-gate\`, \`plan-gate\`, or
\`findings-checkpoint\`. Use \`status: implementing\` for runtime/source/test
implementation. Checkpoints update \`phase\`; they do not pause the cycle.
\`.sage\` diagnosis, planning, and capture may proceed without
\`active_session_id\` when they do not change ownership/lifecycle/control
frontmatter. If an active manifest has \`active_session_id\`, only that runtime
session may perform implementation/control mutations; otherwise ask for
handoff/parking or create a separate intake. Treat \`status: paused\` and
\`status: intake\` as parked, resumable work. Parked work may be
manifest-only/capture-only and is not implementation-active until explicit
continuation.
\`sage status\` shows active work separately from paused/intake; \`sage doctor\`
diagnoses structural issues such as actionable work placed in \`.sage/docs/\`.
Closed cycle manifests use \`status: closed\`, \`phase: closed\`, and
\`resolution: shipped | superseded | folded_into | rejected\`; \`status:
completed\` remains valid for completed artifacts such as \`plan.md\`,
\`spec.md\`, and \`root-cause.md\`.

### Skills Before Assumptions

If a Sage skill exists for the current task, read and follow it. Skills live
in \`.agents/skills/\`; their metadata is for discovery and \`SKILL.md\` is
loaded only when relevant. For ambiguous Standard+ work, start with the Sage
router/navigator skill instead of guessing from general training.

### Artifact Router

Decisions that affect the project must be recorded. Specs, plans,
ADRs, and briefs go through the Artifact Router:

- Durable project knowledge, ADRs, and analyses → \`.sage/docs/\`
- Initiative deliverables → \`.sage/work/<cycle>/\`
- Initiative-specific research → \`.sage/work/<cycle>/research/\`
- Actionable TODOs/backlog → current \`manifest.md\`/\`plan.md\` or a minimal intake cycle
- Checkpoint decision-worthy outcomes → \`.sage/decisions.md\`
- Agent behavior corrections/learnings → \`.sage-memory/\`

Do not ask the user where to store artifacts. If an actionable finding belongs
to another existing cycle, record a capture-only update in that cycle. If it is
uncertain or unrelated to the current cycle, create a minimal intake manifest
with \`needs-triage\`. Cross-cycle capture must stay capture-only: same-cycle
\`.sage/work/<cycle>/\` artifacts, \`.sage/decisions.md\`, and narrow
\`.sage-memory/\` learning are allowed, but runtime/code/test implementation
belongs to a resumed or newly approved workflow. Do not put actionable work in
\`.sage/docs/\`.

### Recovery-First Safe Auto-Fix

Sage may use safe auto-fix only for reversible state/metadata hygiene that does
not change product behavior, priority, scope, risk, or ownership. Allowed
classes include: minimal intake manifest creation for clear capture items;
inferable frontmatter/handoff repair; deterministic finding routing;
single-candidate continue; and same-cycle documentation scope updates.

Hard stop instead of auto-fix for implementation without approved artifacts;
scope expansion; destructive actions; conflicting instructions; ambiguous repo ownership;
or multiple equivalent active/resumable cycles. Every safe auto-fix must record
durable audit evidence in \`.sage/.auto-fixes.log\`: detected state, why it
was safe, what changed, resulting state, severity, and next legal move.

### Target Repo Ownership

The current working directory / edited repository owns workflow state.
The edited repository owns state, memory, gates, and recovery. Its
\`.sage/\`, \`.sage-memory/\`, lifecycle state, and gate config are
authoritative for the task. The Sage framework repository must not impersonate
target repo workflow state when Sage is invoked from another repo.

If repo ownership is ambiguous, hard-stop and ask which repository is the
target. Do not auto-fix across repository boundaries. If the user explicitly
names another repository as the target for capture-only work, that repository
owns the new intake state; create only a new \`.sage/work/<cycle>/manifest.md\`
there and do not continue implementing it from the original repo/thread.
Absolute paths outside the target repo are out of scope unless they are
part of an explicitly requested capture-only intake or match this new-intake-only
capture path.

Do not write \`.sage/**\` outside the target repo. Source/runtime/test/
instruction behavior changes require the proper Sage workflow and \`status:
implementing\`. Config changes are calibrated: single-file config-only
Add/Update may be Lightweight only when it matches the structural
allowlist; multi-file/security/hooks/instruction/generated or uncertain config
changes require workflow state.
Same-turn self-created artifacts are not approval.

### Checkpoints And Done

Never skip human approval on briefs, specs, plans, or final
deliverables. Show the work. Wait for approval. Never change scope
unilaterally.

Build spec and plan checkpoints must preserve both approval paths:
[A] Subagent review and [S] Skip review. Do not collapse them into
generic approval. The [A] wording must explicitly authorize Codex to spawn a
read-only subagent so it satisfies the active spawn_agent tool policy.

### Targeted Recall For Subagent Review

Do not preload memory for every task. For Sage-related review/fix/research
subagents where durable context or prior corrections may affect judgment:
set/select the current project with \`sage_memory_set_project\` before any
SageMemory operation, then search self-learning with exactly
\`filter_tags: ["self-learning"]\`. If SageMemory tools are unavailable, read
\`.sage-memory/self-learning.md\` only when the target project provides it; if
that fallback is unavailable, say so. Report which prevention rules affected
the review. Never use the generic learning tag as the self-learning query.

Before any completion checkpoint: tests exist, tests pass (paste
actual output, do not summarize), implementation matches the spec.

When a learning moment occurs, store it via self-learning before
proceeding. This is automatic, not optional.

Decision logging policy:
- \`.sage/decisions.md\` is a decision log, not a process log. Only decision-worthy events go there: accepted root cause/plan/scope, scope expansion, closeout, durable project rule, or user direction changing priority/ownership/risk/future behavior.
- Auto-review and Auto-QA verdicts are process evidence. Process-only frontmatter, intermediate revisions, pure bookkeeping, and closed-cycle reconciliation do not require decision entries.
- Keep the 50 newest decisions in \`.sage/decisions.md\`; rotate older entries to \`.sage/decisions-archive.md\` newest first from the primary checkout only. Worktrees may exceed 50 and must not touch archive.
- Archive read is search-first: use \`rg\`, read fragments; full archive read requires a named reason.

${const_section}

## Project State

All Sage state lives in \`.sage/\`:
- \`decisions.md\` — shared decision log (agent + human)
- \`docs/\` — project-level knowledge (analyses, ADRs, guides)
- \`work/\` — per-initiative deliverables with YAML frontmatter
- \`gates/\` — quality gate scripts and activation config

<!-- SAGE-MANAGED-END — do not modify or move this line. Content above is regenerated. Content below is yours. -->
EOF
}

# ------------------------------------------------------------------
# Prefix-managed write (preserve user territory below marker)
# ------------------------------------------------------------------

_write_with_marker_strategy() {
    local target_file="$1"
    local sage_prefix="$2"

    if [ ! -f "$target_file" ]; then
        # Fresh file — just write the prefix (which ends with the marker).
        printf '%s\n' "$sage_prefix" > "$target_file"
        return 0
    fi

    if grep -q '^<!-- SAGE-MANAGED-END' "$target_file"; then
        # Marker present — preserve everything from the marker line onward.
        local user_territory
        user_territory="$(awk '/^<!-- SAGE-MANAGED-END/{found=1} found{print}' "$target_file")"
        # Strip the marker line itself from user_territory (we re-emit it via prefix).
        user_territory="$(printf '%s' "$user_territory" | sed -n '2,$p')"
        if [ -n "$user_territory" ]; then
            printf '%s\n%s\n' "$sage_prefix" "$user_territory" > "$target_file"
        else
            printf '%s\n' "$sage_prefix" > "$target_file"
        fi
        return 0
    fi

    # No marker — back up the user file, then regenerate fresh.
    local ts backup
    ts="$(date -u +%Y%m%dT%H%M%S)"
    backup="${target_file}.user-backup-${ts}"
    cp "$target_file" "$backup"
    printf 'generate-codex: AGENTS.md had no SAGE-MANAGED-END marker — saved your previous content to %s\n' "$backup" >&2
    printf '%s\n' "$sage_prefix" > "$target_file"
}

# ------------------------------------------------------------------
# Public entry point
# ------------------------------------------------------------------

compose_agents_md() {
    local target="$1"
    local cli_preset="$2"
    local sage_framework="$3"

    local rule_1a_variant
    rule_1a_variant="$(_detect_rule_1a_variant "$target")"

    local effective_preset
    effective_preset="$(_resolve_effective_preset "$target" "$cli_preset")"

    local sage_prefix
    sage_prefix="$(_build_sage_prefix "$effective_preset" "$sage_framework" "$target" "$rule_1a_variant")"

    _write_with_marker_strategy "$target/AGENTS.md" "$sage_prefix"

    cat <<EOF
[stage 3] composed AGENTS.md
  preset_cli=$cli_preset
  preset_effective=$effective_preset
  rule_1a_variant=$rule_1a_variant
  path=$target/AGENTS.md
EOF
}
