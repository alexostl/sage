# Decision: `.sage` As The Working Source Of Truth

## Context

During the documentation rewrite for `sage-codex`, the repository had a split
working context:

- approved initiative state was already being created in `.sage/work/`
- broader repo-operational knowledge still depended on legacy materials in
  `to-rewrite-in-sage/`
- deeper canonical docs also existed in `docs/`, `runtime/`, `core/`, and
  `develop/`

Without an explicit decision, future sessions could treat `.sage` and
`to-rewrite-in-sage/` as parallel working sources of truth, which would weaken
Sage's state-first operating model.

## Decision

For normal project execution in `sage-codex`:

- `.sage/` is the working source of truth
- `.sage/docs/` holds durable repo-operational knowledge
- `.sage/work/` holds initiative-specific state and workflow artifacts
- `.sage/decisions.md` holds the running decision trail

Deeper reference detail may still live elsewhere in the repository, but future
sessions should reach it through `.sage` guidance rather than through ad hoc
rediscovery.

`to-rewrite-in-sage/` is legacy input only. It may be used while checking parity
of the rewritten `.sage` artifacts, but it is not part of the normal working
loop.

## Consequences

### Positive

- future sessions have a clear first-stop working surface
- the repository follows Sage methodology more faithfully
- operational knowledge becomes easier to maintain than a scattered set of
  historical notes
- legacy materials gain a clean exit condition instead of lingering indefinitely

### Ongoing responsibility

- if a fact is repeatedly needed to operate on this repo, promote it into
  `.sage/docs/` or `.sage/decisions.md`
- keep `.sage` concise and operational rather than turning it into a full mirror
  of public docs
- keep canonical deep references accurate in the broader repo paths they point to

### Anti-patterns to avoid

- using `to-rewrite-in-sage/` as the first-stop guide for active work
- storing reusable project-operational knowledge only in chat history
- creating a second operational notes surface outside `.sage/`

## Legacy-Folder Deletion Condition

`to-rewrite-in-sage/` can be deleted once all of the following are true:

1. A future working session can start from `.sage/` and locate normal repo
   operating guidance without opening the legacy folder.
2. `.sage/docs/learn-sage-codex-repository-map.md` identifies where deeper
   canonical repo truth lives.
3. `.sage/docs/learn-sage-codex-working-model.md` explains how new work and
   reusable knowledge should be recorded.
4. `.sage/docs/learn-sage-codex-codex-platform-context.md` covers the practical
   Codex/self-hosting context needed for repo work.
5. No remaining operational concept in the legacy folder is needed for normal
   execution unless it has been migrated, summarized, or explicitly discarded.

Until those conditions hold, the folder is archival input for parity checks
only.
