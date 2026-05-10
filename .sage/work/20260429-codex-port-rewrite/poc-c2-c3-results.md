---
title: "M0 PoC C2 + C3 + §12 active-claims results"
type: empirical-findings
status: completed
phase: build-m0
cycle: 20260429-codex-port-rewrite
parent: plan.md
created: "2026-04-30"
codex_version: "0.126.0-alpha.15"
poc_dirs: ["~/Developer/sage-poc-m0/c2", "~/Developer/sage-poc-m0/c3", "~/Developer/sage-poc-m0/c4", "~/Developer/sage-poc-m0/c5"]
spec_amendments_applied: true
---

# M0 PoC C2 + C3 + §12 active-claims results

Empirical M0 closure for cycle [20260429-codex-port-rewrite] —
spec §12 PoC C2 (PostToolUse payload), PoC C3 (timing/race), plus
re-verification of all active §12 claims on installed Codex
0.126.0-alpha.15.

**Bottom line:** all spec assumptions hold. Two **factual corrections**
applied to spec text (not architecture). No deferrals required, no
risks materialized. Greenlight to enter M1.

---

## Summary table

| Claim | Spec ref | Result | Evidence path |
|---|---|---|---|
| PostToolUse fires after `apply_patch` | §12 PoC C2 | ✓ PASS | `~/Developer/sage-poc-m0/c2/.codex/payloads/*-PostToolUse-apply_patch-stdin.json` |
| Payload includes patch args | §12 PoC C2 | ✓ PASS (with detail) | `tool_input.command` = apply_patch DSL; `tool_response` = stringified JSON with exit_code |
| Hooks are synchronous (no race) | §12 PoC C3 | ✓ PASS | c3 timeline: Patch 2 PreToolUse fires 1.19s AFTER Patch 1 PostToolUse-END |
| `apply_patch` writes to disk BEFORE PostToolUse | §6.4 | ✓ CONFIRMED | hook-saw-file mtime ≤ PostToolUse-START |
| `exit 2` denies + stderr surfaced | §12 row 3 | ✓ PASS | "Command blocked by PreToolUse hook: <our stderr>" surfaced verbatim to agent |
| Multi-hook PASS_ALL_FIRE | §12 row 5 | ✓ PASS (ordered, not unordered) | c4 fire log: 3/3 fired sequentially in registration order |
| PreToolUse payload has `tool_name` + tool args | §12 row 6 | ✓ PASS (field is `tool_input`, not `tool_args`) | c2 PreToolUse stdin |

---

## T0.1 — PoC C2: PostToolUse payload schema

**Setup:** `~/Developer/sage-poc-m0/c2/` — minimal `.codex/` rig with
`config.toml` (codex_hooks=true, sandbox=workspace-write,
approval_policy=never) and `hooks.json` registering all 5 events
(SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop) to
`./.codex/hooks/capture-payload.sh <TAG>`. The capture script writes
nanosecond-timestamped `<NS>-<TAG>-stdin.json` files. Trust entry
appended to `~/.codex/config.toml`.

**Run:** `codex exec --skip-git-repo-check --json` with prompt
*"Use apply_patch to create hello.txt with content 'hi from poc c2'."*

**PostToolUse payload (verbatim, the §6.4 anchor):**

```json
{
  "session_id": "019ddd98-f039-7833-a70a-172b469640a2",
  "turn_id": "019ddd98-f7f0-7873-8539-782192cbbd58",
  "transcript_path": "/Users/alexostl/.codex/sessions/2026/04/30/rollout-2026-04-30T10-54-40-019ddd98-f039-7833-a70a-172b469640a2.jsonl",
  "cwd": "/Users/alexostl/Developer/sage-poc-m0/c2",
  "hook_event_name": "PostToolUse",
  "model": "gpt-5.5",
  "permission_mode": "bypassPermissions",
  "tool_name": "apply_patch",
  "tool_input": {
    "command": "*** Begin Patch\n*** Add File: hello.txt\n+hi from poc c2\n*** End Patch\n"
  },
  "tool_response": "{\"output\":\"Success. Updated the following files:\\nA hello.txt\\n\",\"metadata\":{\"exit_code\":0,\"duration_seconds\":0.0}}",
  "tool_use_id": "call_9Ybpx8g7ApvM3fSr8gUxBziO"
}
```

**Key findings (vs spec §6.4 + §12 PoC C2 assumptions):**

1. **`tool_input` and `tool_response` BOTH present in single hook
   firing.** Spec §6.4 only claimed args; bonus is structured
   `tool_response` with `metadata.exit_code` — hook can short-circuit
   on `exit_code != 0` without running git diff.
2. **`tool_response` is a STRINGIFIED JSON** (one extra
   `jq -r '.tool_response | fromjson'` step). Not a JSON object directly.
3. **`tool_input.command` is the apply_patch DSL** (`*** Begin Patch
   ... *** End Patch`), NOT a parsed file list. The hook must parse
   `*** Add File: <path>`, `*** Update File: <path>`, `*** Delete File:
   <path>` lines to extract `claimed_paths`. (Spec §6.3 step 1 already
   says "extract list of file paths the patch claims to touch" — but
   doesn't make explicit it requires a small parser; ~10 lines of
   `grep -E '^\*\*\* (Add|Update|Delete) File: '` + `awk '{print $4}'`.)
4. **Bonus context fields**: `cwd`, `session_id`, `turn_id`,
   `transcript_path`, `model`, `permission_mode`, `tool_use_id`. All
   useful for audit (ADR-7 / turn-audit.sh).

**Stop hook payload (bonus capture, useful for §6.5 turn-audit):**

```json
{
  "stop_hook_active": false,
  "last_assistant_message": "Created `hello.txt` with exactly..."
}
```
Plus all session/turn/transcript context fields. `last_assistant_message`
is plaintext, NOT JSON — directly usable for spec/plan/decisions.md
mention scans (§6.5 step 4 phase-jump probe).

---

## T0.2 — PoC C3: Race-condition timing test

**Setup:** `~/Developer/sage-poc-m0/c3/` — same `config.toml` shape;
`hooks.json` registers PreToolUse + PostToolUse + Stop on `apply_patch`
matcher to three timed scripts. PostToolUse hook does:
```bash
TS_START=<ns>
echo "$TS_START PostToolUse-START (will sleep 2s)" >> timeline.txt
[ -f race-target.txt ] && echo "$TS_START hook-saw-file mtime=$(stat -f %m race-target.txt) size=..." >> timeline.txt
sleep 2
TS_END=<ns>
echo "$TS_END PostToolUse-END (slept 2s)" >> timeline.txt
```

**Run:** prompt *"Create race-target.txt with content 'v1' via
apply_patch. Then immediately overwrite race-target.txt with 'v2' via
apply_patch. Two consecutive patches."*

**Timeline (verbatim, ns-precision):**

```
1777539892907777000 PreToolUse-START                    [Patch 1 begin]
1777539892907777000 PreToolUse-END
1777539893227360000 PostToolUse-START (will sleep 2s)   [+320ms]
1777539893227360000 hook-saw-file mtime=1777539892 size=3   [v1 already on disk]
1777539895267460000 PostToolUse-END (slept 2s)          [+2.04s]
1777539896455513000 PreToolUse-START                    [Patch 2: +1.19s AFTER P1 PostEnd]
1777539896455513000 PreToolUse-END
1777539896501684000 PostToolUse-START (will sleep 2s)
1777539896501684000 hook-saw-file mtime=1777539896 size=3   [v2 on disk]
1777539898532837000 PostToolUse-END (slept 2s)
1777539899887615000 Stop-FIRED                          [+1.35s after final PostEnd]
```

**Final disk state:** `race-target.txt` = `v2` (correct ordering preserved).

**Key findings:**

1. **PostToolUse is BLOCKING.** Patch 2 PreToolUse fires 1.19s AFTER
   Patch 1 PostToolUse-END (which slept 2s). Codex waited for the hook
   to exit before invoking the next tool call. **This is the spec §6.4
   recovery-flow assumption** — confirmed.
2. **No interleaving.** Patch 1 events complete in full before Patch 2
   begins. apply_patch hook chains are serialized.
3. **`apply_patch` commits to disk BEFORE PostToolUse fires.** At
   PostToolUse-START, `race-target.txt` already has the patched mtime
   + size = 3 ("v1\n"). PostToolUse semantics = post-write hook, as
   spec §6.4 assumes.
4. **PreToolUse fires BEFORE patch is applied.** No PreToolUse hook
   instance saw the file in pre-patch state — confirms ordering is
   PreToolUse → mutation → PostToolUse.
5. **Stop hook fires LAST**, 1.35s after final PostToolUse-END (LLM
   final-message assembly window). §6.5 turn-audit timing budget
   reasonable.

**Race-condition risk:** NULL. No window where agent reads patched
file before hook completes — because tool-call-N+1 cannot begin until
hook-call-N exits. ADR-1 + §6.4 recovery flow is safe.

---

## T0.3 — Re-verify §12 active claims

### Claim A: `exit 2` denies + stderr surfaced to agent context

**Setup:** `~/Developer/sage-poc-m0/c5/` — PreToolUse(apply_patch) →
`deny.sh` which prints to stderr then `exit 2`.

**Run:** prompt *"Use apply_patch to create blocked.txt. If denied,
just report the error."*

**Result:**
- `blocked.txt` was NOT created on disk.
- Agent's final message contained verbatim:
  > `Command blocked by PreToolUse hook: DENIED-BY-HOOK: this apply_patch is blocked for testing exit-2 semantics.`
- Codex prefixes hook stderr with the literal string
  `Command blocked by PreToolUse hook: ` then appends our stderr.
- Hook fired exactly once (no retry).

**Implications for spec §6.3:**
- Deny semantics CONFIRMED on Codex 0.126.0-alpha.15.
- The "Sage:" prefix on our deny messages will appear AFTER the
  Codex prefix → final agent-visible string is:
  `Command blocked by PreToolUse hook: Sage: paths outside cycle scope: ...`
  This is verbose but safe — agent still parses our scope info.
- No retry mechanism means a deterministic deny is final per tool call.

### Claim B: Multi-hook PASS_ALL_FIRE

**Setup:** `~/Developer/sage-poc-m0/c4/` — PreToolUse(apply_patch)
registers 3 hooks (`multi-1.sh`, `multi-2.sh`, `multi-3.sh`), each
appends `<NS> multi-N-FIRED` to a shared log.

**Run:** prompt *"Use apply_patch to create multi.txt with content
'test multi-hook fire-all'."*

**Fire log:**
```
1777540002350952000 multi-1-FIRED
1777540002608528000 multi-2-FIRED
1777540002868243000 multi-3-FIRED
```

**Final disk:** `multi.txt` = `test multi-hook fire-all` (all 3 ran
+ patch went through).

**Findings:**
1. ✓ All 3 hooks fired (PASS_ALL_FIRE confirmed).
2. **Ordering:** SEQUENTIAL in REGISTRATION ORDER (multi-1 → multi-2
   → multi-3 with ~258ms / ~260ms gaps). NOT unordered as the spec
   text said.

**Spec correction:** §12 row 5 said `PASS_ALL_FIRE_UNORDERED`. Actual
behavior is `PASS_ALL_FIRE_ORDERED` (sequential, registration order).
This is BETTER than spec assumed — framework hook chains can rely on
order without explicit serialization. But the field name is wrong in
spec text and must be corrected.

**Implications for spec §5 / §6:** when generator emits
`hooks.json` with framework hook BEFORE user-override hook (the
common case), the framework hook runs first and any audit/log writes
land before the user hook can interfere. No explicit `flock` needed
just for ordering — only for concurrent-session writes (separate
issue, ADR-7 mitigation already present).

### Claim C: PreToolUse payload includes tool_name + args

**Evidence (from T0.1 capture):**
```json
{
  "session_id": "...",
  "turn_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "hook_event_name": "PreToolUse",
  "model": "gpt-5.5",
  "permission_mode": "bypassPermissions",
  "tool_name": "apply_patch",
  "tool_input": {
    "command": "*** Begin Patch\n*** Add File: hello.txt\n+hi from poc c2\n*** End Patch\n"
  },
  "tool_use_id": "..."
}
```

**Findings:**
1. ✓ `tool_name` present (= `"apply_patch"`).
2. ✓ Args present — but field is named **`tool_input`**, not
   `tool_args`. Spec text uses `tool_args` in 5 places.
3. ✓ All bonus context (session/turn/transcript/cwd/model/permission_mode/
   tool_use_id) present. Useful for audit pathways.

**Spec correction:** rename `tool_args` → `tool_input` in spec text.
Architecture unaffected — same data, different field name.

---

## T0.4 — Decision: spec amendment

**Verdict:** Two SURGICAL spec amendments required (factual corrections,
zero architecture impact).

| Amendment | Spec lines | Change |
|---|---|---|
| **A1** — `tool_args` → `tool_input` (5 refs) | 1267, 1271, 1273, 1373, 1902, 2015 | rename field; add note that `tool_input.command` is apply_patch DSL (not parsed file list) |
| **A2** — `PASS_ALL_FIRE_UNORDERED` → `PASS_ALL_FIRE_ORDERED` (2 refs) | 1901, 2015 | sequential registration-order semantics |
| **A3** (additive) — §6.4 PostToolUse payload empirical anchor | 1368-1370 | replace "Empirical anchor missing — PoC C2 needed before cutover" with confirmed schema + `tool_response` shortcut detail |
| **A4** (additive) — §13.3 row updated with M0 closure | 2015 | add T0.1/T0.2/T0.3 verification timestamp |

**No deferrals required.** No risk-register additions. No new ADRs.

These amendments are applied in this M0 close — see spec.md diff
+ §13.3 row update.

---

## Outputs (artifacts)

- This file: `.sage/work/20260429-codex-port-rewrite/poc-c2-c3-results.md`
- Captured payloads (T0.1):
  `~/Developer/sage-poc-m0/c2/.codex/payloads/*.json` (10 files,
  one per hook firing — SessionStart, UserPromptSubmit, PreToolUse,
  PostToolUse, Stop)
- Race timeline (T0.2):
  `~/Developer/sage-poc-m0/c3/.codex/payloads/timeline.txt`
- Multi-hook fire log (T0.3 claim B):
  `~/Developer/sage-poc-m0/c4/.codex/payloads/multi-fire.log`
- Deny hook log (T0.3 claim A):
  `~/Developer/sage-poc-m0/c5/.codex/payloads/deny.log`

**Cleanup:** PoC dirs preserved under `~/Developer/sage-poc-m0/`
for re-run on next Codex bump (per spec §13.3 watch protocol).
Trust entries persist in `~/.codex/config.toml`.

---

## Implications for M1 implementation

1. **`pre-tool-validate.sh` (T1.5):** payload-extract step is
   `jq -r '.tool_input.command'` (was `.tool_args`). Then 10-line
   apply_patch DSL parser to extract `claimed_paths` from
   `*** Add File:` / `Update File:` / `Delete File:` lines.

2. **`post-tool-check.sh` (T1.6):** can short-circuit early on
   `jq -r '.tool_response | fromjson | .metadata.exit_code'` ≠ 0
   (apply_patch already failed, no diff needed). This wasn't in spec —
   bonus optimization from T0.1.

3. **`turn-audit.sh` (T1.7):** Stop payload has plaintext
   `last_assistant_message` — directly scan for spec/plan/
   decisions.md mentions without parsing the transcript file.
   Spec §6.5 step 4 phase-jump probe simplified.

4. **Hook chain ordering (T1.5/T1.6/T1.7):** generator can rely on
   registration order — framework hook before user-override hook in
   `hooks.json` array means framework hook always runs first. No
   `flock`-for-ordering scaffolding needed.

5. **No spec-amendment churn for v2 deferred items.** PoC findings
   confirm spec architecture; v2 promotion triggers (§13.2) remain
   correct.
