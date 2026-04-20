#!/usr/bin/env python3
"""
Load Sage MCP configuration from Codex TOML or legacy JSON and emit normalized JSON.

Usage:
    python3 load_config.py [project-dir]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

def normalize_json(config: dict) -> dict:
    servers = config.get("mcpServers", config)
    if not isinstance(servers, dict):
        raise SystemExit("Unsupported MCP JSON shape")
    return {"format": "json", "mcpServers": servers}


def parse_string(value: str) -> str:
    return bytes(value[1:-1], "utf-8").decode("unicode_escape")


def split_top_level(value: str, separator: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    in_string = False
    escape = False
    for char in value:
        if in_string:
            current.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
            current.append(char)
            continue
        if char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
        if char == separator and depth == 0:
            part = "".join(current).strip()
            if part:
                parts.append(part)
            current = []
            continue
        current.append(char)
    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def parse_value(raw: str):
    value = raw.strip()
    if value.startswith('"') and value.endswith('"'):
        return parse_string(value)
    if value == "true":
        return True
    if value == "false":
        return False
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [parse_value(part) for part in split_top_level(inner, ",")]
    if value.startswith("{") and value.endswith("}"):
        inner = value[1:-1].strip()
        if not inner:
            return {}
        parsed: dict[str, str] = {}
        for item in split_top_level(inner, ","):
            key, item_value = item.split("=", 1)
            parsed[key.strip()] = parse_value(item_value)
        return parsed
    return value


def parse_codex_toml(path: Path) -> dict:
    servers: dict[str, dict] = {}
    current: dict | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            if section.startswith("mcp_servers."):
                name = section.split(".", 1)[1]
                current = servers.setdefault(name, {})
            else:
                current = None
            continue
        if current is None or "=" not in line:
            continue
        key, value = line.split("=", 1)
        current[key.strip()] = parse_value(value)
    return {"format": "toml", "mcpServers": servers}


def main() -> int:
    start_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    search_order = [
        (start_dir / ".codex" / "config.toml", "toml"),
        (start_dir / ".claude" / "mcp.json", "json"),
        (start_dir / ".sage" / "mcp.json", "json"),
    ]
    for path, kind in search_order:
        if not path.is_file():
            continue
        if kind == "toml":
            payload = parse_codex_toml(path)
        else:
            with path.open("r", encoding="utf-8") as handle:
                payload = normalize_json(json.load(handle))
        payload["source"] = str(path)
        json.dump(payload, sys.stdout)
        sys.stdout.write("\n")
        return 0
    json.dump({"format": None, "source": None, "mcpServers": {}}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
