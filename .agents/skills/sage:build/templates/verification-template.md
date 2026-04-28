---
# Sage verification template — required shape, validated by:
#   runtime/platforms/codex/hooks/lib/verification_check.py
#
# Canonical location: .sage/work/<slug>/verification.md  (slug root, not
# under any phase subdirectory).
#
# Required frontmatter keys: cycle_id, verified_at, scope, closed.
# Required H2 sections, in order:
#   ## Pre-fix reproducer
#   ## Implementation summary
#   ## Test command + pasted output
#   ## Close-out checklist
#
# The "Test command + pasted output" section MUST contain a fenced code
# block with at least one line of real output beyond the command line.
# bin/sage-close and the .githooks/pre-commit hook both reject this file
# if any of these rules fail.
cycle_id: "TODO-replace-with-initiative-slug"
verified_at: "TODO-YYYY-MM-DD"
scope: "TODO-standard-or-comprehensive"
closed: false
---

# Verification: TODO — initiative title

## Pre-fix reproducer

Describe the failing/missing condition that motivated this work — the
exact behavior or finding that proves the work was needed. For a fix:
the bug repro. For a build: the missing capability or the failing
acceptance criterion the spec said to satisfy.

This section answers: "How did we know there was something to do?"

## Implementation summary

What changed, in plain prose. List the files touched, the new modules
or scripts added, and the most important decisions made during
implementation that the spec/plan did not pin down.

This section answers: "What did we actually do?"

## Test command + pasted output

Paste the verbatim command and verbatim stdout/stderr of the test run
that proves the work is complete. The validator requires a fenced code
block with at least one real output line beyond the command. Do not
summarize — paste.

```
TODO command goes here
TODO real output goes here
TODO at least one line beyond the command
```

This section answers: "What evidence proves it works?"

## Close-out checklist

Tick each box, or note explicitly why an item is deferred (with a
follow-up captured in `.sage/decisions.md` or as its own initiative).

- [ ] All plan tasks marked done in plan.md
- [ ] All spec DONE-WHEN criteria satisfied (or explicitly deferred)
- [ ] Tests pass — output pasted above
- [ ] Decisions recorded in `.sage/decisions.md`
- [ ] No unrelated changes mixed into the diff
- [ ] Ready for `bin/sage-close <slug>`

This section answers: "Are we actually ready to ship?"
