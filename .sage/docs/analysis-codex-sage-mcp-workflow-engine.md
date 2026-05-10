---
title: "Analysis — Sage MCP workflow engine for Codex"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
sources:
  - https://developers.openai.com/codex/config-reference#configtoml
  - https://developers.openai.com/codex/hooks
  - https://developers.openai.com/codex/concepts/customization#skills
  - https://developers.openai.com/codex/concepts/sandboxing#configure-defaults
  - https://developers.openai.com/codex/config-reference#requirementstoml
  - https://modelcontextprotocol.io/docs/learn/client-concepts
  - https://modelcontextprotocol.io/specification/draft/client/elicitation
---

# Analysis — Sage MCP Workflow Engine For Codex

## Question

Would implementing Sage as an MCP server for Codex be better than the current
skill plus hook architecture for enforcing Sage workflow guardrails?

## Short Verdict

Yes, with an important caveat.

Sage MCP is a better architecture for the **workflow brain**: state machine,
gate validation, approval proof, status, routing, artifact creation, and
turn-audit decisions. It centralizes Sage logic outside the model's voluntary
memory and gives hooks, skills, and status one shared API.

It is not, by itself, a hard enforcement boundary in `fast-trusted` /
Skip Permissions mode. Harder enforcement still depends on hooks,
permissions/sandbox, admin requirements where available, and git backstops.

## Docs Findings

### Codex Treats MCP As A First-Class Tool Surface

Codex config supports native `mcp_servers.<id>` entries with stdio or HTTP
servers, environment, startup timeout, tool timeout, `enabled_tools`,
`disabled_tools`, and `required`.

This means a Sage MCP server can be installed and made required for Codex
sessions. It can expose a narrow set of workflow tools rather than forcing
all Sage methodology into `AGENTS.md` or public skills.

### Skills Are Reusable Instructions, Not Enforcement

OpenAI's Codex customization docs describe skills as repeatable workflow
capabilities with progressive disclosure: metadata first, `SKILL.md` only
when chosen, references/scripts only when needed.

This matches the observed failure: skills are a good UX and methodology
surface, but they do not themselves maintain a workflow state machine. Codex
can still drift after loading a skill.

### Hooks Can Call A Shared Validator, But Remain Guardrails

Codex hooks can run deterministic scripts during the agent lifecycle.
`PreToolUse`, `PermissionRequest`, and `PostToolUse` match tool names including
MCP tool names. `UserPromptSubmit` can add developer context or block a prompt.
`Stop` can continue the turn with a new prompt.

However, the docs explicitly state `PreToolUse` is a guardrail, not a complete
enforcement boundary, because equivalent work can often happen through another
tool path. `PostToolUse` also cannot undo side effects.

Therefore, MCP should not replace hooks. MCP should become the shared policy
engine that hooks call.

### Skip Permissions Still Removes Hard Boundaries

Codex sandbox docs say `danger-full-access` removes filesystem and network
boundaries, and `approval_policy = "never"` means Codex does not stop for
approval prompts.

So in the user's normal Skip Permissions profile, Sage MCP improves behavioral
reliability and observability, but cannot honestly be described as hard
filesystem enforcement.

### Admin Requirements Can Make This Stronger For Teams

`requirements.toml` can constrain security-sensitive settings, pin hooks, and
allowlist MCP servers by name and identity. This is most relevant for
`strict` profile or team/enterprise setups.

For local self-host `fast-trusted`, the practical value is still high, but the
user can bypass local config by choosing full access.

### MCP Roots Are Not A Security Boundary Either

MCP client concepts describe roots as useful for context scoping, accident
prevention, and workflow organization, but not as guaranteed enforcement,
because servers run code the client cannot fully control. This reinforces the
same posture: MCP is excellent for workflow structure, not sufficient alone as
a security boundary.

### MCP Elicitation Could Support Approval UX Later

The MCP elicitation spec allows servers to request structured information from
users through the client during a tool call, subject to client support. Codex
config already mentions granular approval handling for MCP elicitations.

This could eventually support `sage_record_approval` or `sage_checkpoint`
flows, but it should not be required for v1. V1 can use normal assistant
checkpoints plus disk-backed proof.

## Better Target Architecture

The best architecture is not "MCP instead of skills and hooks." It is:

- `AGENTS.md`: compact contract that says Sage MCP is the workflow authority.
- Public workflow skills: UX entry points and phase-specific methodology.
- Sage MCP: state machine, validation, approval proof, routing, artifact API,
  checkpoint generation, and audit.
- Hooks: lifecycle adapters that call Sage MCP or the same underlying library.
- `.sage/`: durable source of truth.
- `sage status`: user-visible diagnostic over the same MCP/state engine.
- Pre-commit: final repository backstop.

## Proposed MCP Tools

Minimal v1:

- `sage_status`
- `sage_route`
- `sage_next_action`
- `sage_validate_transition`
- `sage_validate_mutation`
- `sage_record_approval`
- `sage_create_artifact`
- `sage_checkpoint`
- `sage_audit_turn`

Implementation should keep the real logic in a shared local library so hooks
can call it directly without needing to make MCP self-calls. The MCP server
then exposes that same library to Codex as tools.

## What This Solves Better Than Current Design

Sage MCP directly improves:

- pseudo-Sage detection;
- `[A]`, `[R]`, `[S]` semantics;
- active initiative and phase recovery;
- "what is allowed next?" decisions;
- approval proof from disk;
- hook/status consistency;
- testability of Sage workflow logic independent of Codex behavior;
- token cost, because large process logic moves out of prompt text.

## What It Does Not Solve Alone

Sage MCP does not fully solve:

- agent ignoring the MCP tool when not forced by hooks/instructions;
- filesystem mutation in `danger-full-access`;
- unsupported tool paths that hooks do not intercept;
- prompt-level social drift before any tool call unless `Stop` or
  `UserPromptSubmit` catches it;
- MCP server outages unless `required = true` is used and status reports it.

## Implementation Cost

Estimated complexity is higher than shell-only hooks, but cleaner over time.

New work:

- define canonical workflow/gate schema;
- implement shared Sage state library;
- implement MCP server wrapper;
- wire Codex config generation for `[mcp_servers.sage]`;
- refactor hooks to call shared validator;
- update `sage status`;
- add regression tests and outcome pilots.

Existing assets reduce cost:

- `runtime/mcp/` already has MCP discovery/proxy utilities;
- Codex config generator already emits MCP config from legacy Sage MCP config;
- proposed ADRs already define workflow state machine and approval proof;
- hooks already exist and can be converted from bespoke logic to adapters.

## Recommendation

Adopt Sage MCP as the central workflow engine for the Codex refactor, but keep
the layered architecture.

Do not describe MCP as hard enforcement in `fast-trusted`. Describe it as the
authoritative workflow brain plus validator. Enforcement strength comes from:

1. model instruction to use Sage MCP;
2. hooks that call the same validator;
3. `required = true` MCP config;
4. strict profile with sandbox/approval/admin requirements;
5. pre-commit and status backstops.

## Design Change Needed

The current architecture should be revised from:

> workflow state machine/gate validator as an internal hook/status library

to:

> Sage Workflow Engine exposed as MCP and reused by hooks/status through a
> shared local library.

That makes MCP the integration surface and the shared library the implementation
core. This avoids duplicating logic while keeping hooks fast and deterministic.
