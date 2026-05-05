#!/bin/sh

message="$1"

if [ -z "$message" ]; then
  printf '{"ok":false,"error":"No message provided"}\n'
  exit 0
fi

if [ "$message" = "fail" ]; then
  printf '{"ok":false,"error":"Mock agent failed on request"}\n'
  exit 0
fi

escaped=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"ok":true,"message":"Mock agent heard: %s"}\n' "$escaped"
