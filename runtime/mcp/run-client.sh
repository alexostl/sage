#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_JSON="$SCRIPT_DIR/package.json"
TSX_BIN="$SCRIPT_DIR/node_modules/.bin/tsx"
SDK_DIR="$SCRIPT_DIR/node_modules/@modelcontextprotocol/sdk"
CLIENT="$SCRIPT_DIR/mcp-client.ts"

if [ ! -f "$PACKAGE_JSON" ]; then
  echo "Error: MCP runtime manifest is missing at $PACKAGE_JSON" >&2
  exit 1
fi

if [ ! -x "$TSX_BIN" ] || [ ! -d "$SDK_DIR" ]; then
  echo "Installing Sage MCP runtime dependencies..." >&2
  (
    cd "$SCRIPT_DIR"
    npm install --no-fund --no-audit --silent --package-lock=false
  )
fi

exec "$TSX_BIN" "$CLIENT" "$@"
