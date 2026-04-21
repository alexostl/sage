#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════╗
# ║  Sage MCP Discovery                                      ║
# ║                                                           ║
# ║  Connects to configured MCP servers, lists available      ║
# ║  tools, and caches the manifest for adapter-native        ║
# ║  instruction surfaces.                                    ║
# ║                                                           ║
# ║  Usage:                                                   ║
# ║    bash discover.sh [project-dir]                         ║
# ║                                                           ║
# ║  Reads from: .codex/config.toml or legacy Sage MCP JSON  ║
# ║  Writes to:  .sage/mcp-manifest.json                     ║
# ╚═══════════════════════════════════════════════════════════╝
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:-.}"
PROJECT="$(cd "$PROJECT" && pwd)"
MCP_CLIENT="$SCRIPT_DIR/mcp-client.ts"
MCP_LOADER="$SCRIPT_DIR/load_config.py"
MCP_RUNNER="$SCRIPT_DIR/run-client.sh"

echo "═══ Sage MCP Discovery ═══"
echo "  Project: $PROJECT"

# ── Find MCP config ──
LOADED_CONFIG=$(python3 "$MCP_LOADER" "$PROJECT" 2>/dev/null || echo '{"format":null,"source":null,"mcpServers":{}}')
MCP_CONFIG=$(printf "%s" "$LOADED_CONFIG" | python3 -c "import json,sys; print(json.load(sys.stdin).get('source') or '')" 2>/dev/null)

if [ -z "$MCP_CONFIG" ]; then
  echo ""
  echo "  ⚠️  No MCP configuration found"
  echo "  Expected: .codex/config.toml, .claude/mcp.json, or .sage/mcp.json"
  echo ""
  echo "  To configure MCP servers for Codex, add entries under [mcp_servers] in .codex/config.toml"
  echo ""

  # Write empty manifest
  mkdir -p "$PROJECT/.sage"
  cat > "$PROJECT/.sage/mcp-manifest.json" << 'EMPTY'
{
  "discovered": null,
  "servers": {},
  "summary": "No MCP servers configured. Add .codex/config.toml, .claude/mcp.json, or .sage/mcp.json to enable."
}
EMPTY

  echo "  ✅ Empty manifest written to .sage/mcp-manifest.json"
  exit 0
fi

echo "  Config: $MCP_CONFIG"
echo ""

# ── Check MCP client available ──
if [ ! -f "$MCP_CLIENT" ]; then
  echo "  ❌ MCP client not found at $MCP_CLIENT"
  exit 1
fi

if [ ! -f "$MCP_RUNNER" ]; then
  echo "  ❌ MCP runner not found at $MCP_RUNNER"
  exit 1
fi

# ── List servers in config ──
SERVERS=$(printf "%s" "$LOADED_CONFIG" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('\n'.join(data.get('mcpServers', {}).keys()))
" 2>/dev/null)

if [ -z "$SERVERS" ]; then
  echo "  ⚠️  No servers found in config"
  exit 0
fi

echo "── Discovering tools from $(echo "$SERVERS" | wc -l) server(s) ──"
echo ""

# ── Discover tools from each server ──
MANIFEST_SERVERS=""
MANIFEST_FAILURES=""
SUMMARY_LINES=""
FAILURE_LINES=""
TOTAL_TOOLS=0
HEALTHY_SERVERS=0
HAS_FAILURES=false

cd "$PROJECT"

for server in $SERVERS; do
  echo -n "  $server: "

  # Call list-tools for this server
  SERVER_STDERR="$(mktemp)"
  TOOLS_JSON=$(bash "$MCP_RUNNER" list-tools --server "$server" 2>"$SERVER_STDERR")
  RUN_STATUS=$?
  RUN_STDERR="$(cat "$SERVER_STDERR")"
  rm -f "$SERVER_STDERR"

  if [ -z "$TOOLS_JSON" ]; then
    echo "❌ failed to connect"
    HAS_FAILURES=true
    if [ -n "$MANIFEST_FAILURES" ]; then
      MANIFEST_FAILURES="$MANIFEST_FAILURES,"
    fi
    ERROR_JSON=$(printf "%s" "${RUN_STDERR:-No output from MCP runner}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
    MANIFEST_FAILURES="$MANIFEST_FAILURES\"$server\":{\"status\":\"error\",\"error\":$ERROR_JSON}"
    FAILURE_LINES="$FAILURE_LINES\n- $server: unavailable"
    continue
  fi

  SERVER_STATUS=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    console.log(data._meta?.servers?.['$server']?.status || 'ok');
  " 2>/dev/null)

  SERVER_ERROR=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const error = data._meta?.servers?.['$server']?.error || '';
    process.stdout.write(error);
  " 2>/dev/null)

  if [ "$RUN_STATUS" -ne 0 ] || [ "$SERVER_STATUS" = "error" ]; then
    ERROR_MESSAGE="${SERVER_ERROR:-${RUN_STDERR:-failed to start or connect}}"
    echo "❌ failed"
    [ -n "$ERROR_MESSAGE" ] && echo "    · $ERROR_MESSAGE"
    HAS_FAILURES=true
    if [ -n "$MANIFEST_FAILURES" ]; then
      MANIFEST_FAILURES="$MANIFEST_FAILURES,"
    fi
    ERROR_JSON=$(printf "%s" "$ERROR_MESSAGE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
    MANIFEST_FAILURES="$MANIFEST_FAILURES\"$server\":{\"status\":\"error\",\"error\":$ERROR_JSON}"
    FAILURE_LINES="$FAILURE_LINES\n- $server: unavailable"
    echo ""
    continue
  fi

  if [ "$SERVER_STATUS" = "disabled" ]; then
    echo "⏸ disabled"
    if [ -n "$MANIFEST_FAILURES" ]; then
      MANIFEST_FAILURES="$MANIFEST_FAILURES,"
    fi
    MANIFEST_FAILURES="$MANIFEST_FAILURES\"$server\":{\"status\":\"disabled\"}"
    FAILURE_LINES="$FAILURE_LINES\n- $server: disabled"
    echo ""
    continue
  fi

  # Count tools and extract names
  TOOL_COUNT=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const tools = data['$server'] || [];
    console.log(tools.length);
  " 2>/dev/null)

  TOOL_NAMES=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const tools = data['$server'] || [];
    tools.forEach(t => console.log(t.name + '|' + t.description.substring(0, 80)));
  " 2>/dev/null)

  echo "✅ ${TOOL_COUNT:-0} tools"

  # Build manifest entry
  TOOLS_ARRAY=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const tools = (data['$server'] || []).map(t => ({
      name: t.name,
      description: t.description || ''
    }));
    console.log(JSON.stringify(tools));
  " 2>/dev/null)

  # Accumulate for manifest
  if [ -n "$MANIFEST_SERVERS" ]; then
    MANIFEST_SERVERS="$MANIFEST_SERVERS,"
  fi
  MANIFEST_SERVERS="$MANIFEST_SERVERS\"$server\":$TOOLS_ARRAY"

  # Build summary line for CLAUDE.md
  TOOL_NAME_LIST=$(echo "$TOOLS_JSON" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8'));
    const tools = data['$server'] || [];
    console.log(tools.map(t => t.name).join(', '));
  " 2>/dev/null)

  SUMMARY_LINES="$SUMMARY_LINES\n- $server: $TOOL_NAME_LIST"
  TOTAL_TOOLS=$((TOTAL_TOOLS + ${TOOL_COUNT:-0}))
  HEALTHY_SERVERS=$((HEALTHY_SERVERS + 1))

  # Print tool details
  echo "$TOOL_NAMES" | while IFS='|' read -r tname tdesc; do
    [ -n "$tname" ] && echo "    · $tname — $tdesc"
  done
  echo ""
done

# ── Write manifest ──
mkdir -p "$PROJECT/.sage"
TIMESTAMP=$(date -Iseconds)

cat > "$PROJECT/.sage/mcp-manifest.json" << MANIFEST
{
  "discovered": "$TIMESTAMP",
  "servers": {$MANIFEST_SERVERS},
  "failures": {$MANIFEST_FAILURES},
  "summary": "$TOTAL_TOOLS tools across $HEALTHY_SERVERS healthy server(s)$( [ "$HAS_FAILURES" = true ] && printf '; some servers failed' )"
}
MANIFEST

echo "── Results ──"
echo "  Total: $TOTAL_TOOLS tools discovered"
echo "  Healthy servers: $HEALTHY_SERVERS"
echo "  Manifest: .sage/mcp-manifest.json"
echo ""

# ── Generate always-on instructions snippet ──
SNIPPET_FILE="$PROJECT/.sage/mcp-snippet.md"
cat > "$SNIPPET_FILE" << SNIPPET
## MCP Tools Available

Use \`bash sage/runtime/mcp/run-client.sh call-tool <server> <tool>\` to call these.
For current framework docs, prefer context7 over training data.
$(echo -e "$SUMMARY_LINES")
$( [ -n "$FAILURE_LINES" ] && printf '\n## MCP Servers Unavailable During Discovery\n%s\n' "$(echo -e "$FAILURE_LINES")" )
SNIPPET

echo "  Instructions snippet: .sage/mcp-snippet.md"
echo ""

if [ "$HAS_FAILURES" = true ]; then
  echo "  ⚠️  Some servers failed to connect. Re-run after fixing configuration."
fi

echo "═══ Discovery complete ═══"
