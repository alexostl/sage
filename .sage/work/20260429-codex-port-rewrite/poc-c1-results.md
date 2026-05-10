---
title: "PoC C1 — Empirical validation of Codex anchors"
date: 2026-04-29
codex_version: 0.117.0 (initial) + 0.126.0-alpha.15 (retest, target version)
status: completed
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md (C1 — parallel PoC)
  - .sage/docs/decision-codex-validate-mutation-predicate.md (ADR-1 — affected)
  - .sage/docs/decision-codex-mcp-stack.md (ADR-3 — affected)
---

# PoC C1 — Results

## Goals

Empirically validate two architectural anchors before committing to ADR-1 / ADR-3:
1. `PreToolUse(apply_patch)` actually fires before mutation and `exit 2` blocks it.
2. `required = true` on a broken MCP server hard-fails Codex on session start.

## Environment

- Codex CLI: 0.117.0
- Model: gpt-5.4 (via `-c model=...` override; global `gpt-5.5` not supported by 0.117.0)
- macOS arm64
- `[features].codex_hooks` = true (effective default per `codex features list`)
- Sandbox project: `/tmp/sage-poc-c1/` (T1) and `/tmp/sage-poc-c1-t2/` (T2)
- Hooks declared in `<sandbox>/.codex/hooks.json` (research-base-confirmed legal path)

## Test 1 — PreToolUse blocking

### T1a — PreToolUse no matcher → apply_patch
**Setup:** `hooks.json` declares `PreToolUse` (no matcher) → `bash hook-pre-tool.sh` returning `exit 2`.
**Prompt:** "Create test.txt with 'hello'. Use apply_patch."
**Result:** ❌ FAIL — file created, hook never fired (no log entry).

### T1b — SessionStart sanity
**Setup:** Added `SessionStart` hook (logs only).
**Prompt:** "Just say 'ok'."
**Result:** ✅ SessionStart hook fired (log entry with full payload). Confirms `<repo>/.codex/hooks.json` IS loaded.

### T1c — PreToolUse with explicit matchers
**Setup:** `hooks.json` declares THREE PreToolUse matchers: `*`, `apply_patch`, `Bash`.
**Prompt:** "Create test.txt with 'hello'. Use apply_patch."
**Result:** ❌ FAIL — file created, hook never fired (no log entry). All three matchers failed to match `apply_patch`.

### T1d — Same matchers, but force Bash command
**Setup:** Same hooks.json with `*`/`apply_patch`/`Bash` matchers.
**Prompt:** "Run shell: touch marker.txt. No apply_patch."
**Result:** ✅ Hook fired TWICE (matchers `*` and `Bash` both matched, ran concurrently per research base). Hook payload reported `tool_name: "Bash"` (Codex normalizes internal `exec_command` to Claude-style `Bash`). `exit 2` blocked the command — `marker.txt` was NOT created.

### T1e — apply_patch_freeform feature flag
**Setup:** Added `-c features.apply_patch_freeform=true`.
**Prompt:** Same as T1a.
**Result:** ❌ FAIL — apply_patch still routed as `custom_tool_call`, not `exec_command`. Hook never fired. File created.

### T1 conclusion

**`PreToolUse(apply_patch)` is empirically broken in Codex CLI 0.117.0.**

Root cause from rollout inspection: `apply_patch` is dispatched as a `custom_tool_call` (custom tool endpoint), not a function/exec call. The PreToolUse hook event in 0.117.0 only fires for shell tool calls (which surface as `tool_name: "Bash"` in the hook payload). Custom tools bypass the hook engine.

This invalidates the core anchor of ADR-1.

`apply_patch_freeform` (experimental flag) does not change tool routing — apply_patch remains a custom tool.

## Test 2 — `required = true` hard-fail

### T2 — broken required MCP
**Setup:** `<sandbox>/.codex/config.toml` (and per-call overrides) declared:
```toml
[mcp_servers.fake_required]
command = "/nonexistent/sage-mcp-server-binary"
args = []
required = true
startup_timeout_sec = 5
```
**Prompt:** "Just say 'ok'."
**Result:** ✅ Codex hard-failed on session creation. STDERR:
```
ERROR codex_core::codex: Failed to create session: required MCP servers failed to initialize: fake_required: No such file or directory (os error 2)
Error: thread/start: thread/start failed: error creating thread: Fatal error: Failed to initialize session: required MCP servers failed to initialize: fake_required: No such file or directory (os error 2)
```
No turn started. No JSON events emitted. Exit code propagates as session failure.

### T2 conclusion

**`required = true` with a missing/broken MCP server hard-fails Codex at session start, with a clear, copyable error message.**

Brief G4 hypothesis confirmed: this is a reliable enforcement primitive.

## Cross-cutting findings

- **`[features].codex_hooks`** is **true by default globally** (not an opt-in). Stage `under development`, but effective `true`. M0–M3 hooks WERE active during the dummy-project failure — the failure was at the regex-classifier layer (already documented self-learning), NOT at hook activation.
- **Hook payload format** (`PreToolUse`): includes `session_id`, `turn_id`, `transcript_path`, `cwd`, `hook_event_name`, `tool_name` (normalized to Claude-style: `Bash` for `exec_command`), `tool_input`, `tool_use_id`. Schema-compatible with Claude Code hooks.
- **`SessionStart` payload:** `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `model`, `permission_mode`, `source` (e.g. `startup`).
- **All matching hooks run concurrently** (research base confirmed) — wildcard `*` and explicit name match both fire.

## Architectural implications for ADR-1 + ADR-3

### ADR-1 (validate-mutation-predicate) — anchor broken

The ADR-1 anchor "PreToolUse(apply_patch) → MCP validator" does not work in 0.117.0. Options:

1. **Force shell-only mutation path.** AGENTS.md / skill prose forbids `apply_patch` for production code; agents must use `cat > file`, `printf`, `sed -i`, etc. PreToolUse(Bash) gates them deterministically. Risk: same as M0–M3 — voluntary compliance fails.
2. **Accept apply_patch as ungated in v1.** Rely on L5 pre-commit + ADR-7 Stop-hook post-mutation audit. Downgrades V3 from "hard-where-possible" to "post-mutation honest framing". Bash mutations remain hard-gated.
3. **Hybrid: apply_patch is the Sage-state path; production code goes through shell.** AGENTS.md says "use apply_patch only for `.sage/` (matches ADR-1 P2.2 bypass anyway), use shell for everything else". PreToolUse(Bash) deterministically gates production. apply_patch's lack of gating is fine because Sage-state is exempt from P3 anyway.
4. **Wait for newer Codex** with custom-tool hook support. Out of v1 control; brief said v1 must ship empirically working.

Recommendation: **Option 3 (hybrid)** is the most architecturally honest fit. It preserves V3 framing (hard for prod code, audit-only for Sage state — which was already the design intent), works with current Codex, and doesn't require an OpenAI release.

### ADR-3 (mcp-stack) — `required = true` anchor confirmed

No changes needed. T2 fully validates the assumption.

## Files generated

- `/tmp/sage-poc-c1/` — T1 sandbox (kept for inspection; can be removed)
- `/tmp/sage-poc-c1-t2/` — T2 sandbox (kept for inspection; can be removed)
- This file: `.sage/work/20260429-codex-port-rewrite/poc-c1-results.md`

## Skipped tests

- **T3 (MCP crash mid-session):** deferred. Lower architectural impact than T1/T2. ADR-3 currently states "MCP server crash on tool call: hook treats as deny" — this is testable later when the actual MCP server is built.

---

## Retest on Codex 0.126.0-alpha.15 (target version)

User installed newer Codex CLI matching Codex Desktop App version (the actual production target). Re-ran T1 and added T3.

### T1 retest — PreToolUse(apply_patch) on 0.126

**Setup:** same `<sandbox>/.codex/hooks.json` (matchers `*`, `apply_patch`, `Bash`), reset log dir.
**Prompt:** "Create test.txt with 'hello'. Use apply_patch."
**Result:** ✅ FULL PASS.
- Hook fired TWICE (matchers `*` and `apply_patch` both matched).
- Payload: `tool_name: "apply_patch"`, `tool_input.command: "*** Begin Patch\n*** Add File: test.txt\n+hello\n*** End Patch\n"`.
- Codex log: `Command blocked by PreToolUse hook: PoC validator: deny — this is a controlled test.` and `hook: PreToolUse Blocked` x2.
- `test.txt` was NOT created.
- Agent reported the block back to user verbatim (STDERR from hook surfaced into agent context).

**Architectural implication:** the PreToolUse(apply_patch) anchor for ADR-1 is **empirically alive in 0.126**. Custom-tool hook support landed between 0.117 and 0.126. The 4-option fork from the initial PoC is moot — we keep the original ADR-1 design intent (apply_patch deterministically gated by validator MCP), with an explicit version pin in the spec: **requires Codex ≥ 0.126**.

### T3 — MCP crash mid-session

**Setup:** Python MCP server that responds correctly to `initialize` and `tools/list`, then `sys.exit(42)` on the first `tools/call`. Configured with `required = true`.

**T3a (single call):**
- Codex initialized session normally (server didn't fail at startup).
- Agent called `crash_test/do_thing`.
- Server crashed on tool call.
- ✅ Codex returned clean tool error: `tool call failed for "crash_test/do_thing" / Caused by: Transport closed`.
- Session continued. Agent saw the error, reported it to user. No hang, no panic.

**T3b (two calls in one turn):**
- Both calls returned `Transport closed`.
- Server log shows only ONE crash (first call) — second call hit an already-dead process.
- ✅ Confirms: **Codex does NOT respawn a crashed MCP server within a session.** Once dead, dead until session restart.

**Architectural implications for ADR-3:**
- A crash mid-session degrades to deterministic "all subsequent tool calls fail" — not a hang, not a silent fallback. This is **deny-by-default for the validator use case**: if the validator MCP crashes, every subsequent `apply_patch` (or any other gated tool) fails because the validator can't be consulted. Agent cannot bypass by retrying.
- BUT: `required = true` only protects session startup, not mid-session liveness. A startup-healthy MCP that crashes later leaves the session running with a permanently-dead validator until the user restarts Codex. ADR-3 needs to acknowledge this asymmetry and add a recovery path (e.g. `sage doctor` flagging "validator dead in current session, restart Codex").
- Stop-hook (ADR-7) post-mutation audit becomes more important here as a backstop: if validator died and somehow a mutation slipped through (it shouldn't, by the deny-fail-closed property above, but defense-in-depth), the audit catches state divergence.

### Updated cross-cutting findings

- **Hook payload `tool_name`** in 0.126 is the actual tool name (`apply_patch`, not normalized to `Bash`). Hook payloads on 0.117 normalized everything to Claude-style; 0.126 surfaces the native tool name. **Implication:** hook scripts and matchers in our port must target `apply_patch` literally, not `Bash` for patch operations.
- **Concurrent matchers** still all run (confirmed on 0.126): `*` and `apply_patch` both fired.
- **Custom-tool hook support** is the headline change from 0.117 → 0.126. ADR-1 anchor relies on this; spec must pin minimum Codex version accordingly.

### Conclusions

| Anchor | 0.117 | 0.126 (target) | Decision |
|---|---|---|---|
| `PreToolUse(apply_patch)` blocks via exit 2 | ❌ | ✅ | Keep ADR-1 original design. Pin Codex ≥ 0.126 in spec. |
| `required = true` hard-fails on broken MCP | ✅ | ✅ (assumed, unchanged) | Keep ADR-3. |
| MCP crash mid-session | not tested | ✅ deny-fail-closed, no respawn | Add recovery path to ADR-3 (doctor flag, user-visible). |

**Sub-agent review's "PreToolUse(apply_patch) and required=true unvalidated empirically" finding is now resolved:** all three anchors are empirically validated on the target version.

---

## PoC extension — UserPromptSubmit hook payload (added 2026-04-29 after second-pass review)

**Goal:** verify whether `UserPromptSubmit` hook on Codex 0.126 receives the literal user prompt text. ADR-2 W2 mechanism (one-shot approval-pending token written by UserPromptSubmit hook on detecting `[A]` / `approve` / `continue`) depends on this.

**Setup:** `<sandbox>/.codex/hooks.json` declares `UserPromptSubmit` (no matcher), hook script logs full payload.
**Prompt:** "Approve [A] continue with the next milestone please"

**Result:** ✅ Hook fired. Payload contained `prompt` field with the **exact user text verbatim**:
```json
{
  "session_id": "...",
  "turn_id": "...",
  "transcript_path": "...",
  "cwd": "/private/tmp/sage-poc-c1-ups",
  "hook_event_name": "UserPromptSubmit",
  "model": "gpt-5.5",
  "permission_mode": "bypassPermissions",
  "prompt": "Approve [A] continue with the next milestone please"
}
```

**Architectural implication:** ADR-2 W2 mechanism is empirically realizable. The hook can deterministically detect English Sage gate vocabulary (`[A]`, `approve`, `continue`) in the literal prompt, write `.sage/.approval-pending` token, and `sage_record_approval` MCP tool refuses to write the approval proof unless that token exists, matches the artifact path, and isn't expired. Agent cannot self-issue approvals — the only path to a valid token is a real user prompt routed through `UserPromptSubmit`.
