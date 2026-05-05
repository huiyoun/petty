#!/bin/sh

target="$1"
agent="${2:-main}"
openclaw_bin="${OPENCLAW_BIN:-openclaw}"
shift 2 2>/dev/null || true

if [ "$#" -gt 1 ]; then
  openclaw_bin="$1"
  shift
fi

message="$1"
connect_timeout="${PETTY_SSH_CONNECT_TIMEOUT:-8}"

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False)[1:-1])'
  else
    awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\r/, ""); if (NR > 1) printf "\\n"; printf "%s", $0 }'
  fi
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

extract_message() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json
import sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    print(raw)
    raise SystemExit(0)

if isinstance(data, dict):
    for key in ("message", "reply", "response", "output", "text", "content"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            print(value)
            raise SystemExit(0)
    print(json.dumps(data, ensure_ascii=False))
else:
    print(raw)
'
  else
    cat
  fi
}

if [ -z "$target" ] || [ -z "$message" ]; then
  printf '{"ok":false,"error":"Usage: openclaw-ssh-agent.sh user@tailscale-host agent-name [remote-openclaw-path] message"}\n'
  exit 0
fi

remote_command="$(shell_quote "$openclaw_bin") agent --local --json --agent $(shell_quote "$agent") -m $(shell_quote "$message")"

if ! output=$(/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout="$connect_timeout" "$target" "$remote_command" 2>&1); then
  escaped=$(printf '%s' "$output" | json_escape)
  printf '{"ok":false,"error":"%s"}\n' "$escaped"
  exit 0
fi

message_output=$(printf '%s' "$output" | extract_message)
escaped=$(printf '%s' "$message_output" | json_escape)
printf '{"ok":true,"message":"%s"}\n' "$escaped"
