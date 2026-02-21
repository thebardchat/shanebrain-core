#!/usr/bin/env python3
"""
MCP Client Helper for AI-Trainer-MAX
Calls ShaneBrain MCP server tools via streamable HTTP.
Zero pip installs — stdlib only (urllib.request, json, sys, os).

Usage:
    python mcp-call.py <tool_name> [json_args]
    python mcp-call.py system_health
    python mcp-call.py search_knowledge "{\"query\":\"family\"}"
    python mcp-call.py vault_add "{\"content\":\"test\",\"category\":\"personal\"}"

Environment:
    MCP_URL — MCP server endpoint (default: http://localhost:8100/mcp)

Output:
    Prints the tool result as clean JSON to stdout.
    Exit code 0 on success, 1 on error.
"""

import json
import os
import sys
import urllib.request
import urllib.error

MCP_URL = os.environ.get("MCP_URL", "http://localhost:8100/mcp")

HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}


def mcp_post(payload, session_id=None):
    """POST to MCP endpoint, return (response_body, headers)."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(MCP_URL, data=data, headers=HEADERS, method="POST")
    if session_id:
        req.add_header("Mcp-Session-Id", session_id)
    resp = urllib.request.urlopen(req, timeout=60)
    body = resp.read().decode("utf-8")
    sid = resp.headers.get("Mcp-Session-Id", session_id)
    return body, sid


def parse_sse(body):
    """Extract JSON from SSE 'data:' lines."""
    for line in body.splitlines():
        if line.startswith("data: "):
            return json.loads(line[6:])
    # Try parsing as plain JSON
    try:
        return json.loads(body)
    except Exception:
        return None


def initialize():
    """Initialize MCP session. Returns session_id."""
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "ai-trainer-max", "version": "1.0"},
        },
    }
    body, session_id = mcp_post(payload)
    result = parse_sse(body)
    if not result or "error" in result:
        raise RuntimeError(f"MCP initialize failed: {body[:200]}")
    return session_id


def call_tool(tool_name, arguments=None, session_id=None):
    """Call an MCP tool. Returns the parsed result content."""
    if session_id is None:
        session_id = initialize()

    payload = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments or {},
        },
    }
    body, _ = mcp_post(payload, session_id=session_id)
    result = parse_sse(body)

    if not result:
        raise RuntimeError(f"No valid response from MCP server")

    if "error" in result:
        raise RuntimeError(f"MCP error: {result['error']}")

    # Extract the text content from the result
    content = result.get("result", {}).get("content", [])
    if content and len(content) > 0:
        text = content[0].get("text", "")
        # Try to parse as JSON for clean output
        try:
            return json.loads(text)
        except (json.JSONDecodeError, TypeError):
            return {"text": text}

    return result.get("result", {})


def main():
    if len(sys.argv) < 2:
        print("Usage: python mcp-call.py <tool_name> [json_args]", file=sys.stderr)
        print("Example: python mcp-call.py system_health", file=sys.stderr)
        print('Example: python mcp-call.py search_knowledge "{\\"query\\":\\"family\\"}"', file=sys.stderr)
        sys.exit(1)

    tool_name = sys.argv[1]
    arguments = {}

    if len(sys.argv) >= 3:
        try:
            arguments = json.loads(sys.argv[2])
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON arguments: {e}", file=sys.stderr)
            sys.exit(1)

    try:
        result = call_tool(tool_name, arguments)
        print(json.dumps(result, indent=2, default=str))
    except urllib.error.URLError as e:
        print(json.dumps({"error": f"Cannot reach MCP server at {MCP_URL}: {e}"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
