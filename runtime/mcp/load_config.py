#!/usr/bin/env python3
"""
Load Sage MCP configuration from Codex TOML or legacy JSON and emit normalized JSON.

Usage:
    python3 load_config.py [project-dir]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import tomllib  # type: ignore[attr-defined]
except ModuleNotFoundError:
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:
        tomllib = None  # type: ignore[assignment]


def normalize_json(config: dict) -> dict:
    servers = config.get("mcpServers", config)
    if not isinstance(servers, dict):
        raise SystemExit("Unsupported MCP JSON shape")
    return {"format": "json", "mcpServers": servers}


def ensure_dict(parent: dict, key: str) -> dict:
    current = parent.get(key)
    if not isinstance(current, dict):
        current = {}
        parent[key] = current
    return current


def parse_string(value: str) -> str:
    if len(value) < 2:
        return value
    quote = value[0]
    body = value[1:-1]
    if quote == '"':
        return bytes(body, "utf-8").decode("unicode_escape")
    return body


def strip_inline_comment(raw_line: str) -> str:
    result: list[str] = []
    quote: str | None = None
    escape = False
    for char in raw_line:
        if quote:
            result.append(char)
            if quote == '"' and escape:
                escape = False
            elif quote == '"' and char == "\\":
                escape = True
            elif char == quote:
                quote = None
            continue
        if char in ('"', "'"):
            quote = char
            result.append(char)
            continue
        if char == "#":
            break
        result.append(char)
    return "".join(result).rstrip()


def split_top_level(value: str, separator: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    quote: str | None = None
    escape = False
    for char in value:
        if quote:
            current.append(char)
            if quote == '"' and escape:
                escape = False
            elif quote == '"' and char == "\\":
                escape = True
            elif char == quote:
                quote = None
            continue
        if char in ('"', "'"):
            quote = char
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


def split_assignment(statement: str) -> tuple[str, str]:
    depth = 0
    quote: str | None = None
    escape = False
    for index, char in enumerate(statement):
        if quote:
            if quote == '"' and escape:
                escape = False
            elif quote == '"' and char == "\\":
                escape = True
            elif char == quote:
                quote = None
            continue
        if char in ('"', "'"):
            quote = char
            continue
        if char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
        elif char == "=" and depth == 0:
            return statement[:index], statement[index + 1 :]
    raise ValueError(f"Unsupported TOML assignment: {statement}")


def split_dotted_key(value: str) -> list[str]:
    return [parse_key_token(part) for part in split_top_level(value, ".")]


def parse_key_token(token: str) -> str:
    stripped = token.strip()
    if not stripped:
        return stripped
    if stripped[0] in ('"', "'") and stripped[-1] == stripped[0]:
        return parse_string(stripped)
    return stripped


def is_value_complete(statement: str) -> bool:
    depth = 0
    quote: str | None = None
    escape = False
    for char in statement:
        if quote:
            if quote == '"' and escape:
                escape = False
            elif quote == '"' and char == "\\":
                escape = True
            elif char == quote:
                quote = None
            continue
        if char in ('"', "'"):
            quote = char
            continue
        if char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
    return quote is None and depth == 0


def iter_statements(text: str) -> list[str]:
    statements: list[str] = []
    buffer: list[str] = []
    for raw_line in text.splitlines():
        line = strip_inline_comment(raw_line).strip()
        if not line:
            continue
        if not buffer and line.startswith("[") and line.endswith("]"):
            statements.append(line)
            continue
        buffer.append(line)
        candidate = "\n".join(buffer)
        if is_value_complete(candidate):
            statements.append(candidate)
            buffer = []
    if buffer:
        statements.append("\n".join(buffer))
    return statements


def parse_value(raw: str):
    value = raw.strip()
    if not value:
        return ""
    if value[0] in ('"', "'") and value[-1] == value[0]:
        return parse_string(value)
    if value == "true":
        return True
    if value == "false":
        return False
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    if re.fullmatch(r"-?\d+\.\d+", value):
        return float(value)
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [parse_value(part) for part in split_top_level(inner, ",")]
    if value.startswith("{") and value.endswith("}"):
        inner = value[1:-1].strip()
        if not inner:
            return {}
        parsed: dict[str, object] = {}
        for item in split_top_level(inner, ","):
            key, item_value = split_assignment(item)
            parsed[parse_key_token(key)] = parse_value(item_value)
        return parsed
    return value


def assign_path(root: dict, path: list[str], value) -> None:
    current = root
    for part in path[:-1]:
        current = ensure_dict(current, part)
    current[path[-1]] = value


def parse_toml_text(text: str) -> dict:
    if tomllib is not None:
        return tomllib.loads(text)

    document: dict[str, object] = {}
    current_path: list[str] = []
    for statement in iter_statements(text):
        if statement.startswith("[[") and statement.endswith("]]"):
            continue
        if statement.startswith("[") and statement.endswith("]"):
            current_path = split_dotted_key(statement[1:-1].strip())
            current = document
            for part in current_path:
                current = ensure_dict(current, part)
            continue
        key, value = split_assignment(statement)
        key_path = split_dotted_key(key)
        assign_path(document, current_path + key_path, parse_value(value))
    return document


def parse_codex_toml(path: Path) -> dict:
    parsed = parse_toml_text(path.read_text(encoding="utf-8"))
    servers = parsed.get("mcp_servers", {})
    if not isinstance(servers, dict):
        servers = {}
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
