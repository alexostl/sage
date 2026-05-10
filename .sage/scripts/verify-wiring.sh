#!/usr/bin/env bash
# Sage comm-style wiring check — runs on SessionStart.
# Silent when wiring OK, warns when `sage update` wiped @ references.
set -e

WIRING='@.sage/docs/comm-style.md'
missing=()

for f in CLAUDE.md AGENTS.md; do
  if [ -f "$f" ] && ! grep -qF "$WIRING" "$f"; then
    missing+=("$f")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "⚠️  comm-style wiring missing w: ${missing[*]}"
  echo "   Przywróć jednym: bash .sage/scripts/reapply-comm-style.sh"
fi

exit 0
