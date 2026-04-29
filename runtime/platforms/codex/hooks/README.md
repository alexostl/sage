# Codex hook scripts

These `*.sh` files are the framework-side bodies that ship into a
project's `.codex/hooks/` directory when `[features].codex_hooks = true`
is set in the project's `.codex/config.toml` and `sage update` runs
the L4 activation pipeline.

For the wiring strategy, identity rule, and shadow-file detection, see:

- [ADR-1: Codex hook activation](../../../../.sage/docs/decision-codex-hook-activation.md)
- [HOOKS.md](../HOOKS.md) — what each hook does at runtime

## Append-only `.versions.txt` invariant

Every framework hook file in this directory has at least one line in
[`.versions.txt`](.versions.txt) recording its sha256. The file is
**append-only**:

- When you modify any `*.sh` here, append the **new** hash on a new
  line in the same commit — keep the old line(s) intact.
- Never edit or delete existing entries.

### Why append-only

`sage update` uses the registry to make a three-way decision when it
finds a file at `.codex/hooks/<name>.sh` in the user's project:

1. Hash matches **current** framework version → up to date, no copy needed.
2. Hash matches a **historical** entry in `.versions.txt` → known older
   framework version, safe to replace with current.
3. Hash matches **nothing** in `.versions.txt` → "shadow file" (user
   custom or unknown origin) → refuse overwrite, surface
   `MISCONFIGURED`, require explicit `--force-codex-hooks` override.

Editing or removing an old entry would break case 2 for any project
still on that version, causing `sage update` to misclassify a known-good
older framework hook as a shadow file and either overwrite it
unexpectedly or block updates.

### Update workflow

```bash
# After editing post-bash.sh:
shasum -a 256 post-bash.sh
# 1234abcd...  post-bash.sh
# Append the new line to .versions.txt — keep the old line!
echo "1234abcd...  post-bash.sh" >> .versions.txt
git add post-bash.sh .versions.txt
git commit -m "feat(codex): tighten post-bash filtering"
```

The PR template's "Codex hook changes" check item exists to catch
forgotten `.versions.txt` updates in review.
