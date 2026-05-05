#!/bin/sh

endpoint="$1"
shift 2>/dev/null || true
token="${PETTY_HTTP_TOKEN:-}"

if [ "$#" -gt 1 ]; then
  token="$1"
  shift
fi

message="$1"
timeout="${PETTY_HTTP_TIMEOUT:-30}"

json_error() {
  if command -v python3 >/dev/null 2>&1; then
    PETTY_ERROR="$1" python3 -c 'import json, os; print(json.dumps({"ok": False, "error": os.environ["PETTY_ERROR"]}, ensure_ascii=False))'
  else
    printf '{"ok":false,"error":"%s"}\n' "$1"
  fi
}

if [ -z "$endpoint" ] || [ -z "$message" ]; then
  json_error "Usage: http-agent.sh https://agent.example.com/chat [bearer-token] message"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  json_error "python3 is required to prepare HTTP JSON."
  exit 0
fi

if [ ! -x /usr/bin/curl ]; then
  json_error "curl is required to call the HTTP agent."
  exit 0
fi

payload=$(PETTY_MESSAGE="$message" python3 -c 'import json, os; print(json.dumps({"message": os.environ["PETTY_MESSAGE"]}, ensure_ascii=False))')
body_file="${TMPDIR:-/tmp}/petty-http-agent-body.$$"
error_file="${TMPDIR:-/tmp}/petty-http-agent-error.$$"

if [ -n "$token" ]; then
  status=$(/usr/bin/curl \
    --silent \
    --show-error \
    --max-time "$timeout" \
    --output "$body_file" \
    --write-out "%{http_code}" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $token" \
    --request POST \
    --data "$payload" \
    "$endpoint" 2>"$error_file")
else
  status=$(/usr/bin/curl \
    --silent \
    --show-error \
    --max-time "$timeout" \
    --output "$body_file" \
    --write-out "%{http_code}" \
    --header "Content-Type: application/json" \
    --request POST \
    --data "$payload" \
    "$endpoint" 2>"$error_file")
fi
curl_status=$?

body=$(cat "$body_file" 2>/dev/null)
curl_error=$(cat "$error_file" 2>/dev/null)
rm -f "$body_file" "$error_file"

if [ "$curl_status" -ne 0 ]; then
  json_error "$curl_error"
  exit 0
fi

case "$status" in
  2*) ;;
  *)
    json_error "HTTP $status: $body"
    exit 0
    ;;
esac

PETTY_HTTP_BODY="$body" python3 -c '
import json
import os

raw = os.environ.get("PETTY_HTTP_BODY", "")
try:
    data = json.loads(raw)
except Exception:
    print(json.dumps({"ok": True, "message": raw.strip()}, ensure_ascii=False))
    raise SystemExit(0)

if isinstance(data, dict):
    ok = data.get("ok")
    if ok is False:
        error = data.get("error") or data.get("message") or "HTTP agent returned an error."
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        raise SystemExit(0)

    for key in ("message", "reply", "response", "output", "text", "content"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            print(json.dumps({"ok": True, "message": value}, ensure_ascii=False))
            raise SystemExit(0)

print(json.dumps({"ok": True, "message": json.dumps(data, ensure_ascii=False)}, ensure_ascii=False))
'
