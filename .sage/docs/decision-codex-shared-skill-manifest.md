---
title: "ADR — Codex shared skill manifest"
status: proposed
date: 2026-04-29
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md (G3, C2, C4)
  - .sage/work/20260429-codex-port-rewrite/manifest.md (Round 3 G3)
  - .sage/work/20260429-codex-port-rewrite/cross-port-survey.md (§4 Q1)
  - .sage/docs/decision-codex-validate-mutation-predicate.md
  - .sage/docs/decision-codex-approval-proof-schema.md
  - .sage/docs/decision-codex-mcp-stack.md
  - .sage/docs/research-codex-port-rewrite-base.md (§4.3, §4.4, §5 row 8, §6.1.7, §6.3.5, §6.3.6)
  - .sage/work/20260429-claude-port-logic-map/map.md (§3.1, §3.3, §6.1, §6.7)
---

# ADR — Shared skill manifest

## Context

Round 3 G3 froze a hard constraint on the rewrite:

> Codex visible skills must equal Claude visible commands, generated
> from one shared source. Adding/removing a public skill is a
> one-place edit.

Three platform facts make this constraint structurally necessary, not
aesthetic:

1. **Codex 8000-char skill discovery cap** (research base §4.3, §5
   row 8, §6.1.7). With ~25 internal `SKILL.md` files in
   `core/capabilities/` plus 16 workflow skills, Codex truncates the
   discovery context. We must mark a small subset as public and keep
   the rest invocation-only.
2. **Codex deprecated custom slash commands on 2026-01-22** (research
   base §4.4). What Sage calls "the build command" on Claude is
   actually a skill mention `$build` on Codex. Same logical
   capability, two surface formats.
3. **Claude port already deploys two surface formats from one
   source** (claude-port-logic-map §3.1): `.claude/commands/<name>.md`
   for direct deploy and `tools/sage-claude-plugin/skills/<name>/SKILL.md`
   for the marketplace plugin. The workflow file in `core/workflows/`
   is the source; the generators translate. There is no
   "shared manifest" today — each generator has its own per-workflow
   case statement, which is the same coupling problem as preambles
   (claude-port-logic-map §6.2). With Codex added, three generators
   would each carry a hand-maintained list.

Today's repo state (verified 2026-04-29):

- `core/workflows/*.workflow.md` — 16 files (analyze, architect,
  autoresearch, build, continue, design, design-review, fix, learn,
  map, qa, reflect, research, review, sage, status). Frontmatter
  carries `name`, `version`, `mode`, `produces`, `checkpoints`,
  `scope`, `user-role`. **No `platforms:` field. No `public:`
  field.** Every generator deploys every workflow.
- `core/capabilities/<group>/<skill>/SKILL.md` — 25 files. These are
  internal building blocks (tdd, plan, specify, sage-navigator,
  build-loop, …). Some are referenced from workflows, some are
  general-purpose. **No platform metadata, no public flag.**
- `core/registry.yaml` — declarative inventory documented as
  "auto-generated from the file system". Currently lists per-skill
  `source`, `version`, `status`, `modes`. **No platform list, no
  public flag, no per-platform display data.** Today's generators do
  not consume it for skill-list decisions.
- Codex generator (`runtime/platforms/codex/setup/generate-codex.sh`)
  iterates `core/workflows/*.workflow.md` and `core/capabilities/*`
  the same way Claude does — no platform-aware filter exists in
  either generator.

We therefore have to pick three things at once:

1. Where the per-skill manifest data lives (file layout).
2. What fields it carries (schema).
3. How the three generators (Claude direct, Claude plugin, Codex)
   read it without each one re-implementing YAML parsing in bash.

## Decision

**Three-part decision, each maps to one open question:**

1. **Per-skill manifest data lives in the existing `core/workflows/<name>.workflow.md`
   and `core/capabilities/<group>/<skill>/SKILL.md` frontmatter,
   extended with new fields `platforms`, `public`, `display`, and
   `mention_aliases`.** No new central `core/skills.yaml`. No new
   sidecar `manifest.yaml` per skill. The workflow file (or skill
   file) is the single source of truth, edited in one place, by the
   author of that skill. **Adding a 17th public skill = creating one
   workflow file with `public: true` and the right `platforms` list.**
2. **A small Python preprocessor at `core/_compile/manifest.py` reads
   every workflow and skill file's frontmatter, validates the new
   fields, and emits a single JSON artifact at
   `core/_compile/skills.compiled.json`.** The compiled JSON is
   git-tracked (so reviewers see manifest diffs in PRs) and is the
   only file the platform generators read. Bash generators do not
   parse YAML directly — they `jq` the compiled JSON. Why this
   matters in practice: bash + awk YAML parsing is brittle (current
   plugin generator awk-parses preamble case statements — known
   pain point per logic-map §3.4). One Python-side validator with
   `ruamel.yaml` is the boring, debuggable choice.
3. **Generators pick public skills by intersecting `public: true`
   with `<this-platform> in platforms`.** Per-platform overrides
   (display name, description, alias, icon) live under
   `display.<platform>` in the same frontmatter. Default is "use the
   top-level `name` and `description`"; only platforms with genuine
   divergence (e.g., Codex `agents/openai.yaml` `display_name`)
   add an override.

The 16-skill baseline from G3 stays — but now each baseline workflow
file carries the matching frontmatter explicitly. Removing one is
flipping `public: false`. Adding one is creating a new workflow file
with `public: true` from the start.

### Why frontmatter, not a central catalog

A central `core/skills.yaml` was considered (option C below). It was
rejected because:

- The skill author would have to edit two places (skill file +
  catalog) every time. The whole point of G3 is one-place edit.
- A central catalog drifts from real skills on disk silently — a
  skill can be deleted from the file system without the catalog
  noticing, or vice versa. Frontmatter cannot.
- The compiled JSON gives us the central-catalog ergonomics
  (queryable, diff-visible, single artifact for downstream tooling)
  without the dual-edit cost.

### Why per-skill, not per-workflow only

Workflows (in `core/workflows/`) are the natural home for the public
16. Capabilities (in `core/capabilities/`) are internal building
blocks. **But the manifest schema applies to both directories
identically**, so internal skills can carry `public: false,
platforms: [claude, codex, antigravity, generic]` and stay
invocation-reachable as `$skill-name` (Codex) or `/skill` shortcut
(Claude) without polluting the discovery palette. Codex semantics
back this: a skill on disk is always callable via `$mention`; the
8000-char cap only governs the default discovery context. (See
research base §4.3 last bullet.)

## Schema

### 3.1 — New frontmatter fields (additive)

These fields are added to the existing frontmatter. Existing fields
(`name`, `version`, `mode`, etc.) are unchanged. Manifest fields
appear under a single `manifest:` key to keep the additive surface
small.

```yaml
---
# existing fields unchanged
name: build
version: "1.0.0"
mode: build
produces: ["Brief (medium+ tasks)", "Spec", "Implementation plan"]
checkpoints: 3
scope: "Single session for medium tasks, multi-session for large"
user-role: "Review and approve at each gate"

# NEW: shared skill manifest fields
manifest:
  public: true                              # in default discovery palette
  platforms: [claude, codex, antigravity, generic]
  display:
    codex:
      allow_implicit_invocation: true       # maps to agents/openai.yaml policy (only emitted when needed)
    claude:
      command_name: "build"                 # default = top-level `name`; override only on rename
      plugin_skill_dir: "build"             # default = top-level `name`
    antigravity:
      workflow_file: "build.md"             # default = "${name}.md"
    generic:
      include_in_template: true             # documentation-only hint
  depends_on: []                            # other skill names this one transitively needs at runtime
---
```

For internal skills (e.g., `core/capabilities/execution/tdd/SKILL.md`)
the same `manifest:` block applies, with `public: false` and a
trimmed `display`:

```yaml
manifest:
  public: false
  platforms: [claude, codex, antigravity]
  display:
    codex:
      allow_implicit_invocation: false      # internal: invocation-only, no auto-discovery
  depends_on: []
```

### 3.2 — Field semantics (validator-enforced)

| Field | Type | Required | Meaning |
|---|---|---|---|
| `manifest.public` | bool | yes | Show in default discovery palette (Claude command list / Codex SKILL.md visible in discovery) |
| `manifest.platforms` | list of enum | yes | Which platforms deploy this skill at all. Enum: `claude`, `codex`, `antigravity`, `generic`. Empty list = skill not deployed anywhere (lint warning). |
| `manifest.display.<platform>` | object | no | Per-platform overrides. Missing = use top-level `name`/`description`. |
| `manifest.display.codex.allow_implicit_invocation` | bool | no | Maps to Codex `agents/openai.yaml.policy.allow_implicit_invocation`. Default `true` for `public`, `false` for non-public. **Only Codex display field emitted in v1.** Other Codex display fields (`display_name`, `icon`, `brand_color`) deferred to v2 — defaults from `name` are sufficient. |
| `manifest.display.claude.command_name` | string | no | Filename stem for `.claude/commands/`. Default = top-level `name`. |
| `manifest.display.claude.plugin_skill_dir` | string | no | Directory name for `tools/sage-claude-plugin/skills/`. Default = top-level `name`. |
| `manifest.depends_on` | list of string | no | Other skill names. Used by `sage doctor` for "broken dependency" checks; not enforced at runtime in v1. |

**SKILL.md `description:` field (Codex discovery surface) does NOT come from this manifest** — it comes from the per-workflow preamble teaser per ADR-6. The manifest is platform-shape; the teaser is workflow content. Two ADRs, one source per concern, no dual-write.

**Validator rejects unknown keys under `manifest.*`** — silent typos are the
worst failure mode for declarative manifests.

### 3.3 — Compiled artifact

`core/_compile/manifest.py` reads every `*.workflow.md` and every
`SKILL.md` under `core/capabilities/`, validates the schema, and
emits `core/_compile/skills.compiled.json`:

```json
{
  "schema_version": 1,
  "compiled_at": "2026-04-29T15:30:00Z",
  "source_root": "core/",
  "char_budget": {
    "codex_discovery_cap": 8000,
    "note": "Discovery cost is per-skill SKILL.md `description:` only (sourced from ADR-6 teaser). Per-skill teaser limit ≤300 chars × 16 public skills ≈ 4800 chars. Compute + enforcement live in ADR-6, not here."
  },
  "skills": [
    {
      "name": "build",
      "source": "core/workflows/build.workflow.md",
      "kind": "workflow",
      "public": true,
      "platforms": ["claude", "codex", "antigravity", "generic"],
      "depends_on": [],
      "display": {
        "codex": {
          "allow_implicit_invocation": true
        },
        "claude": {
          "command_name": "build",
          "plugin_skill_dir": "build"
        }
      }
    }
    /* … 40 entries total: 16 workflows + 25 capabilities … */
  ]
}
```

`char_budget.current_estimate` is computed by summing
`display.codex.short_description` + a few framing characters per
public-on-codex skill. **`sage doctor` reads this field** and fails
if `current_estimate > codex_discovery_cap` (ADR-9 hook). The
estimate is conservative and platform-realistic, not a perfect
simulation of Codex's tokenizer — it gives us a check that survives
adding the 17th skill.

The compiled file is **git-tracked**, not generated at runtime. PRs
that change the manifest carry the diff visibly. CI runs
`manifest.py --check` to verify the JSON matches the YAML sources;
out-of-sync = build fails.

## Generator integration

### 4.1 — Claude direct generator (`generate-claude-code.sh`)

Today: iterates `core/workflows/*.workflow.md` and emits one command
file per workflow under `.claude/commands/`. No filtering.

After this ADR:

```bash
# (sketch)
COMPILED="$CORE/_compile/skills.compiled.json"
for entry in $(jq -c '.skills[] | select(.public == true and (.platforms | index("claude")))' "$COMPILED"); do
    name=$(jq -r '.name' <<<"$entry")
    command_name=$(jq -r '.display.claude.command_name // .name' <<<"$entry")
    src=$(jq -r '.source' <<<"$entry")
    # … write .claude/commands/<command_name>.md from $src …
done
```

`jq` is already a dep of the Claude plugin generator (used for
`hooks.json` writing). No new dependency.

### 4.2 — Claude plugin generator (`generate-plugin.sh`)

Today: iterates `core/workflows/` again, awk-parses preambles, emits
`tools/sage-claude-plugin/skills/<name>/SKILL.md` per workflow with
`disable-model-invocation: true`.

After this ADR: same `jq` filter as above, but uses
`display.claude.plugin_skill_dir`. The plugin's
`disable-model-invocation: true` flag is unchanged — it is a Claude
plugin format detail, not a manifest concern.

### 4.3 — Codex generator (`generate-codex.sh`)

Today: writes `.agents/skills/<name>/SKILL.md` for every skill,
no platform filter, no `agents/openai.yaml` per skill.

After this ADR:

```bash
COMPILED="$CORE/_compile/skills.compiled.json"
for entry in $(jq -c '.skills[] | select(.platforms | index("codex"))' "$COMPILED"); do
    name=$(jq -r '.name' <<<"$entry")
    public=$(jq -r '.public' <<<"$entry")
    # … write .agents/skills/<name>/SKILL.md from source …

    # SKILL.md description: comes from ADR-6 teaser, not from this manifest.
    # agents/openai.yaml is OPTIONAL in v1 — only emit when allow_implicit_invocation
    # diverges from Codex default (i.e., for internal skills with public=false where
    # we want allow_implicit_invocation=false). Public skills get default behavior;
    # no agents/openai.yaml needed.
    allow=$(jq -r '.display.codex.allow_implicit_invocation // (if .public then "true" else "false" end)' <<<"$entry")
    if [ "$public" = "false" ] && [ "$allow" = "false" ]; then
        # … emit minimal .agents/skills/<name>/agents/openai.yaml with policy block …
    fi
done
```

`jq` is already used in `runtime/mcp/json_to_toml.py` adjacent code
paths. No new dependency.

### 4.4 — Antigravity / generic generators (cross-port honesty)

The compiled JSON is platform-agnostic. The Antigravity generator
can adopt the same pattern with no schema change — it filters on
`platforms | index("antigravity")` and reads the `display.antigravity.workflow_file`
override (default `${name}.md`). Antigravity port is **modify-with-care**
under brief C4; this ADR does not modify Antigravity, but it leaves
the migration cost low.

Generic port has no generator; it consumes the compiled JSON as
documentation only. `display.generic.include_in_template` is a hint
for the template README.

## Options considered

### Option A — Per-skill manifest data in existing frontmatter (chosen)

How: add `manifest:` block to each `*.workflow.md` and `SKILL.md`.
Compiler emits JSON.

Plus:
- Author edits one file per skill — matches G3.
- Schema lives next to the skill prose; reviewing a skill = reviewing its manifest.
- No new dual-edit risk; file system and manifest cannot drift.
- Migration is mechanical (script-driven additive frontmatter
  injection — see §migration plan).

Minus:
- 41 files (16 workflows + 25 skills) get an additive frontmatter
  block. Mechanical, but a real PR.
- Validator must be authoritative; bad frontmatter must fail the
  build, not produce a degraded manifest.
- Bash generators must learn `jq`. Both already use `jq` in
  adjacent code, so cost is small but not zero.

### Option B — Workflow frontmatter only, capabilities stay invisible

How: add `manifest:` only to `core/workflows/*.workflow.md`. Internal
skills are out-of-scope for the manifest; they continue to deploy
unchanged.

Plus:
- Smaller change. Touches 16 files, not 41.
- "Manifest" cleanly = "the public 16".

Minus:
- 25 internal skills have no machine-readable platform list. Today
  they ship to every platform indiscriminately, including Antigravity
  where some don't make sense. We bake in that asymmetry.
- Adding a 17th *internal* skill that should not deploy to a
  platform requires editing the per-platform generator (the exact
  problem G3 forbids).
- `sage doctor` cannot answer "is `tdd` available on Codex?" without
  filesystem-walking the deployed output.

### Option C — Central catalog `core/skills.yaml`

How: single file at `core/skills.yaml` with one entry per skill,
all metadata centralized. Skill files do not carry manifest
frontmatter.

Plus:
- One file to read at a glance. PR diffs are local.
- No frontmatter cluster on individual files.

Minus:
- Adding/renaming a skill = edit two places (the skill file and the
  catalog). Direct violation of "one-place edit" from G3.
- The catalog can drift from disk silently. Skill deletion =
  catalog still references it.
- Sage already failed once at "central declarative file vs reality"
  (`registry.yaml` is documented as auto-generated but in practice
  was hand-edited; today it is not consumed by the platform
  generators at all). Repeating the pattern is asking for the same
  drift.

### Option D — Per-skill sidecar `<skill>/manifest.yaml`

How: each skill directory gets `manifest.yaml` next to `SKILL.md`.
Frontmatter unchanged.

Plus:
- Manifest is structurally separable from SKILL.md prose.
- YAML-only, no embedded YAML parsing inside markdown.

Minus:
- Two files per skill. Author edits two files per change.
- Workflows under `core/workflows/` are not directories; `<name>.workflow.md`
  is a single file. To match Option D, we'd promote each workflow to
  a directory — a much bigger structural change.
- Frontmatter parsers already exist throughout Sage (Python +
  workflow auto-pickup uses YAML-in-markdown). Adding a parallel
  `manifest.yaml` parser doubles the parse surface for no win.

### Option E — Codex-only manifest (ignore G3's cross-platform constraint)

Mentioned for completeness. Rejected on the spot — G3 explicitly
forbids it.

## Trade-offs

- **Bash + jq vs. native YAML parse.** Bash generators read JSON,
  not YAML. Compiler is Python (consistent with brief C3 + ADR-3
  D1). Trade: one extra build step (`manifest.py`) and a
  git-tracked compiled artifact, in exchange for not implementing
  YAML-in-bash. Compiled artifact must stay in sync — CI check
  catches drift.
- **Frontmatter accumulation in `*.workflow.md`.** Workflow files
  already carry 7 fields; adding `manifest:` makes them 8. The
  block is structured (one nested key) so prose readability stays
  acceptable.
- **Per-platform display overrides could grow unbounded.** v1 ships
  with three overrides per public-on-codex skill (display_name,
  short_description, allow_implicit_invocation). If a future
  platform adds five more keys, the manifest grows. Validator
  rejects unknown keys to keep the schema tight; a new platform
  schema = explicit additive PR.
- **`depends_on` is documentation-only in v1.** Runtime
  dependency-resolution between skills is a v2 concern. v1
  uses the field for `sage doctor` lint warnings only.
- **8000-char cap estimation is conservative.** The estimate is the
  sum of `short_description` + framing chars per public Codex
  skill. The real Codex tokenizer count may be lower (some chars
  are < 1 token). We accept "estimate is a slight over-count" as
  the safe direction. If the over-count blocks a legitimate add,
  we tune the estimator, not the cap.

## Failure modes

- **Generator runs but compiled JSON is stale.** Bash generator
  reads old JSON, emits old skill list. CI check (`manifest.py
  --check`) blocks the PR if `skills.compiled.json` is out of
  sync with sources. `sage doctor` re-runs the compile and reports
  drift to the user. Migration plan §6 includes this CI step.
- **Author adds a skill on disk without `manifest:` block.**
  Compiler treats missing block as schema error and fails the
  build with the file path. Default behavior is NOT
  "auto-deploy everywhere" — that would silently bloat Codex
  discovery and hit the 8000-char cap.
- **Author flips `public: true` for a 17th skill, busts the 8000-char
  cap.** Compiler emits the budget number; `sage doctor` checks it;
  CI surfaces the over-budget condition with a clear message
  ("Codex discovery cap projected at 8420 chars, over budget by
  420; consider trimming `short_description`s or making one
  skill non-public"). Author can either trim or accept the over-budget
  with an explicit `manifest.budget_override: true` flag (not in v1
  schema; reserved for v2 if pattern emerges).
- **Manifest field collides with platform's surface format.**
  Example: Codex `agents/openai.yaml` schema changes upstream and
  invalidates `display.codex.display_name`. Generator catches
  "missing field" at YAML emission time and fails with a clear
  pointer. We rely on `codex_min_version: 0.126` (ADR-1, ADR-3) to
  fix the schema target.
- **Honest framing for v1 (per ADR-1 P2.2 / ADR-2 W2 forge framing):**
  the manifest is a build-time artifact. **An agent that wants to
  bypass the manifest can edit `skills.compiled.json` and re-run a
  generator.** We do not pretend this is a hard boundary. Detection:
  the compiled artifact is git-tracked; an unexpected diff to it
  shows up in `git diff` and in pre-commit (L5 backstop). Same
  honest-framing model as the rest of the rewrite — guardrail for
  the cooperative case, not enforcement against an adversarial
  agent.
- **Cross-port consistency drift.** Antigravity port adopts the
  manifest later than Codex; during the gap, Antigravity skill list
  is generator-internal while Codex/Claude are manifest-driven.
  Acceptable in v1 (brief C4: Antigravity is modify-with-care).
  Manifest schema is platform-agnostic by design; adoption is
  per-port and gated on owner readiness.

## Consequences

- **ADR-5 (instruction surfaces)** consumes `display.codex.short_description`
  for the `agents/openai.yaml` registration. ADR-5 must specify how
  AGENTS.md references the public skill list — likely a generated
  block under a `# >>> SAGE PUBLIC SKILLS START` marker, sourced from
  the compiled JSON.
- **ADR-9 (sage doctor)** gains three checks:
  1. `skills.compiled.json` matches frontmatter sources (CI also
     runs this).
  2. Codex 8000-char discovery budget not exceeded.
  3. Every `manifest.depends_on` target exists in the manifest.
- **`bin/sage init`** does not change in v1 — manifest is build-time.
  v2 may add `sage skill add <name>` scaffolder that creates a
  workflow file with the right manifest block stub.
- **Outcome harness (ADR-8)** gets a "skill list parity" check: the
  set of public Codex skills must equal the set of public Claude
  commands per the compiled JSON. Drift = test fail.
- **Per-port modify-with-care boundary** (brief C4): Claude port
  generators get a small refactor (jq filter on compiled JSON
  instead of file glob). Antigravity / generic ports unchanged in
  this ADR; their migration is a separate later decision.
- **registry.yaml relationship.** `core/registry.yaml` is documented
  as auto-generated and is not currently consumed by the platform
  generators for skill-list decisions. It lives in `core/`, which
  the brief marks out-of-scope by default. This ADR does not modify
  `registry.yaml`. **v2 cleanup candidate** — once `skills.compiled.json`
  is the working source of truth, a follow-up cycle should either
  (a) kill `registry.yaml` if nothing reads it, or (b) re-project it
  from `skills.compiled.json` if `bin/sage` or `sage status` consume
  it. Audit step before deletion: `grep -r registry.yaml` across
  `bin/`, `runtime/`, `core/`, `.sage/`. Out of scope for this ADR.

## Migration plan

Migration is additive and mechanical. **No skill file is renamed,
deleted, or moved.** The change is "every skill file gains a
`manifest:` block in frontmatter".

Steps (each is a separate commit; PRs reviewed separately):

1. **Land the compiler skeleton.** Create
   `core/_compile/manifest.py` that reads frontmatter from
   `core/workflows/*.workflow.md` and `core/capabilities/**/SKILL.md`,
   tolerates missing `manifest:` blocks (emits warnings, no fail),
   and writes `core/_compile/skills.compiled.json`. Land empty
   compiled JSON. CI not yet enforcing.

2. **Backfill manifest for the 16 public workflows.** One PR. Add
   `manifest: { public: true, platforms: [claude, codex, antigravity, generic] }`
   to each `core/workflows/<name>.workflow.md`. `display.codex` is
   omitted for public workflows (defaults are sufficient in v1 —
   `allow_implicit_invocation` defaults to `true` for public).
   Recompile the JSON. Diff visible.

3. **Backfill manifest for 25 internal capabilities.** One PR. Add
   `manifest: { public: false, platforms: [claude, codex, antigravity], display: { codex: { allow_implicit_invocation: false } } }`
   to each `core/capabilities/*/SKILL.md`. Generic excluded for
   internals (generic has no skill deployment automation per
   cross-port-survey §2.3). The `allow_implicit_invocation: false`
   override is the M3 isolation mechanism — internal skills exist on
   disk but Codex does not auto-suggest them.

4. **Switch on validator strictness.** Update `manifest.py` to fail
   when a workflow or capability lacks the `manifest:` block.
   Enable CI check `manifest.py --check`.

5. **Migrate Codex generator** (`runtime/platforms/codex/setup/generate-codex.sh`)
   to read the compiled JSON and filter on `platforms` and `public`.
   Emit `agents/openai.yaml` per public skill from `display.codex.*`.
   Drop the no-filter file-glob path.

6. **Migrate Claude direct + plugin generators** to the same
   compiled-JSON filter. Equivalent diff to step 5 but per-Claude-target.

7. **Outcome harness check** (lands with ADR-8): "Codex public skill
   set equals Claude public command set" assertion against compiled
   JSON.

**Graceful fallback during steps 1–4:** generators continue to use
their current file-glob path. The compiled JSON is informational
only. **Hard cutover at step 5.** Steps 1–4 land first; step 5
flips the read source. No window where generators emit different
public lists.

## User decisions applied (2026-04-29)

- **`mention_aliases` removed entirely.** User explicitly never
  wants alias-based skill invocation, in any language. Field is not
  in the v1 schema and is not deferred to v2 — the concept is
  rejected. Removing it shrinks the schema and removes a maintenance
  surface that would never be used.
- **`display.codex.short_description` removed.** SKILL.md
  `description:` is sourced from the per-workflow preamble teaser
  (ADR-6). One source per concern; the manifest does not duplicate
  workflow content.
- **`display.codex.display_name` / `icon` / `brand_color` deferred
  to v2.** v1 uses Codex defaults (top-level `name`). If user wants
  Polish display names or branding, that is a v2 concern with a
  schema additive change at that point.
- **`registry.yaml` left untouched.** It lives in `core/` (out of
  scope per brief). Logged as v2 cleanup candidate — see
  Consequences section.

## Open questions for review

These are remaining points where the user (or the next reviewer)
should push back if my reading is wrong. None of them require a
Batch-1 ADR revision.

1. **Is `core/_compile/` an acceptable home for the compiled
   artifact?** Alternative: `.sage/.compile/` (git-tracked under
   the project's own state tree). I chose `core/_compile/` because
   the artifact is part of `core/`'s build output, not project
   state.
2. **Generic port has `manifest.display.generic.include_in_template`
   but no automation reads it.** Field is documentation-only. If
   user prefers no field at all for generic, the schema gets a
   touch tighter.

## Status: proposed

Awaiting user approval at design checkpoint after Batch 3 + spec.md.
