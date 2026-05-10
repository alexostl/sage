#!/usr/bin/env bash
# Sage comm-style wiring re-apply — idempotent.
# Wstrzykuje @.sage/docs/comm-style.md po H1 + pustej linii w CLAUDE.md i AGENTS.md.
set -e

WIRING='@.sage/docs/comm-style.md'

for f in CLAUDE.md AGENTS.md; do
  [ -f "$f" ] || continue
  grep -qF "$WIRING" "$f" && continue
  awk -v w="$WIRING" 'BEGIN{done=0}
    /^# / && !done {print; getline; print; print w; done=1; next}
    {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "✓ wiring re-applied w $f"
done
