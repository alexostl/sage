# Self-Hosting Sage

Private capability guide for bootstrapping the Sage framework repository itself
with Sage methodology on this branch.

This is intentionally not part of the public product contract. Treat it as a
branch-local maintainer capability.

## What It Does

`--self-host` allows `sage init` to run inside the Sage framework repository
without creating a nested `sage/` copy.

Instead, it:

- reuses the current framework checkout in place
- creates `.sage/`
- generates platform files such as `CLAUDE.md`, `AGENTS.md`, `.claude/`, and
  `.codex/config.toml`
- leaves the repository root as the working framework source

## Why It Exists

Public Sage intentionally blocks `sage init` inside the framework repo to avoid
accidental recursive setup.

On this private capability branch, the goal is different:

- use Sage methodology while building Sage itself
- keep the public product behavior unchanged elsewhere

## Usage

From the root of the framework repository:

```bash
sage init --self-host --platform claude-code,codex
```

If you want to invoke the local branch copy directly:

```bash
bash bin/sage init --self-host --platform claude-code,codex
```

## Result

Expected generated surfaces:

- `.sage/`
- `CLAUDE.md`
- `.claude/`
- `AGENTS.md`
- `.agents/skills/`
- `.codex/config.toml`

Expected non-result:

- no nested `sage/` directory is created

## Update Flow

After self-host init, standard regeneration should work from the framework repo:

```bash
sage update
```

Because the framework repo already is the source checkout, `update` regenerates
platform files and preserves `.sage/` without needing a nested framework copy.

## Limits

- This capability is for framework maintainers only.
- Keep it on private or capability branches unless you make a deliberate
  product decision to publish it.
- Do not assume upstream wants this behavior.
