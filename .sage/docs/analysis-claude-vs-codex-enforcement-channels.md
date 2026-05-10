---
title: "Claude vs Codex — enforcement channels deep dive"
type: analysis
status: completed
date: 2026-04-29
scope: custom
artifact_prefix: analysis
related:
  - .sage/docs/analysis-codex-enforcement-gap.md
  - .sage/docs/analysis-codex-enforcement-surface-audit.md
  - .sage/work/20260429-codex-port-architecture-redesign/spec.md
  - .sage/work/20260429-codex-port-architecture-redesign/brief.md
audience: next-architect-session
---

# Claude vs Codex — enforcement channels deep dive

**Purpose.** Capture findings from a 2026-04-29 conversation that pressure-tested
the previous gap analysis. These findings re-frame *which channel* actually
drives Sage compliance on Claude Code, and what that implies for the Codex
port redesign. Intended as primary input for the next architect session.

This document does not supersede `analysis-codex-enforcement-gap.md` — it
extends it with three previously unstated dimensions and one empirical
observation that may change the prioritization.

---

## 1. Slash command vs skill — three-layer mechanical difference

The previous analysis described slash commands and skills as differing in
"PREAMBLE injection." That framing is incomplete. The mechanical difference
sits in three layers that need to be separated for design purposes.

### Layer A — Who initiates the invocation

| | Claude slash command | Codex skill |
|---|---|---|
| Trigger | User types `/sage:build` | User types `$build` **or** agent decides to load skill from description match |
| Initiator | Always user | User **or** agent |
| Determinism | 100% — slash always fires file injection | Partial — agent can fail to recognize the right moment |

Slash command is a **user-initiated event with deterministic file injection**.
Skill auto-loading (the agent-initiated path) introduces an additional point
of failure: the agent may not select the skill, or may select it late.

### Layer B — Authority framing in the model context

Text injected into the model context is not "neutral text." The model was
trained on how text is *labeled*.

- Slash command file content lands in conversation as a **user message
  (or system-level injection by the harness)**. The model interprets it as
  *"the user instructed this; high-authority instruction for this turn."*
- Auto-loaded skill body lands as a **reference document the agent itself
  fetched**. The model interprets it as *"documentation I retrieved to
  learn how to do something."*

This is not hair-splitting. The same imperative line — `MUST EXIST. No
exceptions.` — produces measurably different compliance depending on
whether it sits in user/system framing or in skill-body framing. Models are
trained to *obey* user/system instructions and to *learn from* reference
documents. Two different modes.

Implication: even if Codex generator pre-pends a PREAMBLE to `SKILL.md`,
that PREAMBLE inherits skill-body framing and is structurally weaker than
the same text inside `.claude/commands/sage:build.md`.

### Layer C — Determinism of the injection moment

- Slash command injects content **at one specific moment**: after a user
  prompt with `/`, before the model's first generated token. Always.
- Skill body can be loaded mid-response, between tool calls, or never. Codex
  decides *when* to attach skill content. Less deterministic, opens windows
  where the model has already started responding "in build mode" before it
  actually saw the PREAMBLE.

---

## 2. UserPromptSubmit hook as a slash-command equivalent

The hook **can** mechanically replicate slash-command-with-PREAMBLE. It
fires before each user prompt, deterministically, and can inject arbitrary
text. This neutralizes Layers A and C, and partly Layer B (hook output is
typically system-reminder-framed, closer to slash-command framing than
skill-body framing).

But three caveats apply, and the previous M1+M2+M3 attempt
(commit `a6f1391`, reverted as "empirical dead end") hit them.

### Caveat 1 — Which PREAMBLE to inject

Hook fires every prompt, regardless of intent. Three options:

1. **Inject all PREAMBLEs always** — token bloat, signal-to-noise drops,
   model starts ignoring.
2. **Classify intent in the hook and inject the right PREAMBLE** — previous
   try used regex; reverted because regex misclassifies natural-language
   inputs reliably. Spec section "Layer 5 — UserPromptSubmit" rules this
   out: *"The prompt should not classify via regex."*
3. **Inject a meta-PREAMBLE that asks the model to classify** — works, but
   shifts the imperative one level back. Concrete imperatives like
   *"spec.md MUST EXIST"* still need to come from somewhere else. This is
   the path the new spec takes.

Slash command sidesteps this entirely because the *user* did the
classification by typing `/sage:build`.

### Caveat 2 — Token budget per turn

Hook fires **every turn**. Slash command fires **once on workflow entry**;
the PREAMBLE then sits in conversation history.

If the hook injects stable text every turn → KV cache hit, cost similar to
`AGENTS.md` repetition.
If the hook injects state-aware text ("you are at phase=plan") → cache miss
every turn, full re-processing of that segment. Materially more expensive,
and the asymmetry compounds over long sessions.

### Caveat 3 — Framing relative to model-loaded skill body

Even with system-reminder framing on hook output, the **skill body** is
still loaded by the agent as a reference document. Final shape:

```
[hook-injected system reminder with PREAMBLE]    ← imperative, authoritative
[skill body with procedure]                       ← reference, "documentation"
```

vs Claude:

```
[.claude/commands/sage:build.md = PREAMBLE + procedure]  ← single block, single framing, authoritative
```

Smaller asymmetry than no-hook Codex, but non-zero.

---

## 3. Token economics — corrected understanding

Previously assumed: Claude re-injects PREAMBLE every turn. **Wrong.**

Actual mechanics (best understanding, not 100% verified against harness
internals):

- **`CLAUDE.md`** — included in system context **every turn**. Stable
  prefix → KV cache hit → cheap.
- **Slash command file** — fires **once** on slash invocation. Content
  lands as a single user message in history; sits there for remainder of
  session. Cached as old prefix on subsequent turns.
- **Skill body** — loaded on-demand, once, as reference doc.

Codex hook implementation cost depends on text stability:

- Stable hook text → cache hit, cost comparable to `AGENTS.md` repetition.
- State-aware hook text (per-turn variation) → cache miss every turn,
  measurably more expensive over a session.

Design implication: state-aware nudges are valuable but expensive. The
nudge should be as stable as possible while still surfacing current gate.
A reasonable split: stable boilerplate that fits the cache + small variable
tail with current state.

---

## 4. Empirical observation that may reframe priorities

User reports: in their actual workflow on Claude Code, they **rarely type
`/sage:build` themselves**. The agent proposes the workflow via Zone 1
options, the user picks `[1]`, and the agent then *behaves* as if it is in
the build workflow.

If this is accurate (and it likely is, because users select via numbered
options far more than they type slash commands), one consequence follows:

**The per-command PREAMBLE in `.claude/commands/sage:build.md` is probably
not firing in most of this user's sessions.** Slash commands in Claude Code
are user-typed events. Without a user-typed slash, the file is not read,
and the PREAMBLE is not injected.

If true, the dominant compliance channel on Claude in this user's actual
practice is:

1. `CLAUDE.md` (always-on, ~352 lines, imperative, in system every turn).
2. Skill bodies in `sage/skills/` (loaded as reference when invoked).
3. SessionStart hook context injection.

**Per-command PREAMBLE is a backup that fires only when the user actually
types a slash.**

This needs verification before being treated as a finding. Two checks
worth running before architect session commits to a design:

- Does Claude Code harness fire slash commands when the agent presents
  numbered options and the user picks `[1]`? Or does the agent simply
  continue conversationally without invoking the slash? Documentation
  on `<command-name>` tags in the system reminders suggests slashes fire
  only on user typing, but worth confirming.
- Does Claude Code surface `<command-name>` in conversation when slash
  was invoked? Inspecting a transcript can confirm.

If the observation holds, the gap analysis priority shifts:

- Previous Critical: C1 (PREAMBLE injection for skills).
- Possibly correct Critical: **bring `AGENTS.md` to parity with `CLAUDE.md`
  in size, tone, and lifecycle behavior**, because that is the channel
  doing most of the work.

This does not invalidate the layered runtime design in
`20260429-codex-port-architecture-redesign/spec.md` — but it changes which
layer to prioritize first.

---

## 5. Why did M2 (imperative `AGENTS.md`) fail empirically

Open question. Commit `a6f1391` revertéd M1+M2+M3 as "empirical dead end"
without a captured reason in `.sage/`. This is the highest-leverage
unknown for the next architect session.

Hypotheses worth testing:

1. **`AGENTS.md` may not be in system context every turn the way
   `CLAUDE.md` is.** If Codex loads it once at session start and then drops
   salience, imperative tone fades after ~20 turns. Should be checked
   against Codex documentation.
2. **Skill body loading may displace `AGENTS.md` salience.** When agent
   loads a skill mid-session, attention may shift to the freshly loaded
   document; always-on layer loses priority in practice even if formally
   present.
3. **Distance from decision moment.** Imperative rules in `AGENTS.md` may
   be too far from the moment the model decides to violate them to
   actually intervene. Rules need to fire close to the decision.
4. **Codex training prior on `AGENTS.md`-style files differs from
   Claude's prior on `CLAUDE.md`.** Hard to verify externally, but
   plausible — they are different model families with different
   instruction-following profiles.

Without identifying the actual reason, any redesign that leans on
imperative `AGENTS.md` risks hitting the same invisible ceiling. **Recommended
first step for the architect session:** dig out the M2 test artifacts (logs,
session transcripts, anything that captured the failure mode) before
committing to a design direction.

---

## 6. Hook + state detection — design sketch

User proposed: hook injects meta-PREAMBLE, then if-branches based on
whether a workflow is currently active. This is the same direction as
spec Layer 4 (Workflow State Machine). Realistic mechanics:

### State sources

1. **Artifact state** (`.sage/work/*/frontmatter`) — most reliable.
   Deterministic, persisted, independent of conversation history. Tells
   you *which initiatives are open*. Does not tell you *whether the
   current turn relates to them*.
2. **Decision log** (`.sage/decisions.md` head) — recency signal. Tells
   you *where in the workflow we last were*. Limited freshness signal.
3. **Transcript / message history** — best signal for "are we still
   discussing this initiative." Open question whether Codex
   `UserPromptSubmit` hooks have access to transcript or only the current
   prompt + metadata. **Verify before designing around this.**

### "We left the workflow 30 turns ago" problem

No clean solution. Heuristics:

- **Stale by timestamp** — `last_active` field in frontmatter; if older
  than N hours, mark stale. Imperfect: long projects revisit cold work.
- **Explicit exit signal** — workflow close (`/sage:reflect` finalize, `[A]`
  on final checkpoint flipping `status: completed`) is the clean signal.
  Requires workflow discipline.
- **Trust the model with flagged ambiguity** — hook injects "active
  initiative X exists, may be stale, you classify." Simplest, least
  deterministic, lets the model adjudicate.

Realistic combination: frontmatter `status` + `last_active` timestamp +
flagged ambiguity + model classification. Spec calls this acceptable
fuzziness.

### Algorithm sketch

```
on UserPromptSubmit:
  active = read .sage/work/*/frontmatter where status in {in-progress, in-review}
  recent_decisions = head .sage/decisions.md (last 3 entries)

  if no active:
    inject: meta-PREAMBLE (routing reminder, ~50 tokens)

  elif active and fresh (last_active < N minutes):
    inject: focused PREAMBLE for that workflow's gates
            ("active build X at phase=plan; if this turn relates to it,
              spec MUST exist before edits; [A] = REVIEW; ...")
            + short meta-PREAMBLE for "else classify"

  else (active but stale):
    inject: lightweight reminder
            ("active initiative X exists but is stale; if this turn is
              unrelated, ignore; if not, /sage:continue first")
```

Key design rule: **the hook does not classify whether the current turn is
"in workflow." It surfaces state and lets the model classify.** Hook sees
disk; model sees prompt. Classification belongs where the prompt is.

---

## 7. Inputs the next architect session should not have to re-discover

- The three-layer model (initiator / framing / determinism) for slash
  command vs skill. Don't compress back to "PREAMBLE injection."
- The empirical observation about user not typing slashes. **Verify it
  before treating as finding.** If true, it changes priority order.
- The token-economics correction (PREAMBLE injected once on slash, not
  per-turn). Don't design around the wrong assumption.
- The M2 unknown. **Investigate before redesigning.** Highest-leverage
  open question.
- The state-detection design sketch — sources, stale problem, model-as-
  classifier rule.
- The framing constraint: even with hook injection, skill-body framing
  remains weaker than slash-command-file framing. Design must account for
  this if it relies on skill bodies for imperatives.

## 8. What this analysis does not claim

- Does not claim Claude harness internals are fully understood. Several
  mechanics here are best-guess from documented behavior + system-reminder
  patterns. Verify against Anthropic Claude Code docs before treating as
  ground truth.
- Does not claim the layered runtime design in
  `20260429-codex-port-architecture-redesign/spec.md` is wrong. Most of it
  remains valid. The shifts proposed are: (a) prioritize understanding M2
  failure first, (b) reconsider whether per-command PREAMBLE replication
  is a top priority given user's actual usage, (c) treat hook + state
  machine as the realistic equivalent path, accepting it is not 1:1 to
  slash commands.
- Does not propose a new architecture. That is the next architect session's
  job, with these findings as input.
