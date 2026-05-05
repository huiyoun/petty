#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request


API_BASE = "https://api.telegram.org/bot{token}/{method}"


class TelegramAgentError(Exception):
    pass


class TelegramAPIError(TelegramAgentError):
    def __init__(self, description: str, response: dict) -> None:
        super().__init__(description)
        self.description = description
        self.response = response

    @property
    def migrate_to_chat_id(self) -> int | None:
        parameters = self.response.get("parameters") or {}
        value = parameters.get("migrate_to_chat_id")
        return value if isinstance(value, int) else None


def emit_ok(message: str) -> None:
    print(json.dumps({"ok": True, "message": message}, ensure_ascii=False))


def emit_error(message: str) -> None:
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))


def resolve_token(value: str) -> str:
    if value.startswith("env:"):
        env_name = value[4:]
        token = os.environ.get(env_name, "")
        if not token:
            raise TelegramAgentError(f"Environment variable is empty: {env_name}")
        return token

    return value


def api_call(token: str, method: str, payload: dict, timeout: int = 35) -> dict:
    url = API_BASE.format(token=token, method=method)
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        raw = error.read()
    except Exception as error:
        raise TelegramAgentError(str(error)) from error

    try:
        decoded = json.loads(raw.decode("utf-8"))
    except Exception as error:
        raise TelegramAgentError("Telegram returned invalid JSON.") from error

    if not decoded.get("ok"):
        description = decoded.get("description") or "Telegram API request failed."
        raise TelegramAPIError(description, decoded)

    return decoded


def send_message(token: str, chat_id: int | str, text: str) -> dict:
    payload = {"chat_id": chat_id, "text": text}
    try:
        return api_call(token, "sendMessage", payload, timeout=15)["result"]
    except TelegramAPIError as error:
        if error.migrate_to_chat_id is None:
            raise

        migrated_chat_id = error.migrate_to_chat_id
        return api_call(
            token,
            "sendMessage",
            {"chat_id": migrated_chat_id, "text": text},
            timeout=15,
        )["result"]


def flush_pending_updates(token: str) -> int | None:
    response = api_call(
        token,
        "getUpdates",
        {"timeout": 0, "limit": 100, "allowed_updates": ["message", "edited_message"]},
        timeout=10,
    )
    updates = response.get("result") or []
    if not updates:
        return None

    max_update_id = max(update.get("update_id", 0) for update in updates)
    return max_update_id + 1


def message_from_update(update: dict) -> dict | None:
    message = update.get("message") or update.get("edited_message")
    return message if isinstance(message, dict) else None


def message_text(message: dict) -> str:
    text = message.get("text") or message.get("caption") or ""
    return text.strip()


def same_chat(message: dict, chat_id: int | str) -> bool:
    chat = message.get("chat") or {}
    actual = chat.get("id")
    return str(actual) == str(chat_id)


def parse_args(argv: list[str]) -> tuple[str, str, int, str, str]:
    if len(argv) < 4:
        raise TelegramAgentError(
            "Usage: telegram-agent.py <bot-token|env:NAME> <chat-id> "
            "[--timeout seconds] [--prefix text] message"
        )

    token = resolve_token(argv[1])
    chat_id = argv[2]
    timeout_seconds = int(os.environ.get("PETTY_TELEGRAM_TIMEOUT", "90"))
    prefix = os.environ.get("PETTY_TELEGRAM_PREFIX", "")

    index = 3
    while index < len(argv) - 1:
        option = argv[index]
        if option == "--timeout" and index + 1 < len(argv) - 1:
            timeout_seconds = int(argv[index + 1])
            index += 2
        elif option == "--prefix" and index + 1 < len(argv) - 1:
            prefix = argv[index + 1]
            index += 2
        else:
            raise TelegramAgentError(f"Unknown option: {option}")

    message = argv[-1]
    if not message.strip():
        raise TelegramAgentError("No message provided.")

    return token, chat_id, timeout_seconds, prefix, message


def main(argv: list[str]) -> int:
    try:
        token, target_chat_id, timeout_seconds, prefix, message = parse_args(argv)
        bot = api_call(token, "getMe", {}, timeout=10)["result"]
        bot_id = bot["id"]

        next_offset = flush_pending_updates(token)
        sent = send_message(token, target_chat_id, f"{prefix}{message}")
        chat_id = sent["chat"]["id"]
        sent_message_id = sent["message_id"]

        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            poll_timeout = max(1, min(10, int(deadline - time.time())))
            payload = {
                "timeout": poll_timeout,
                "limit": 100,
                "allowed_updates": ["message", "edited_message"],
            }
            if next_offset is not None:
                payload["offset"] = next_offset

            updates = api_call(token, "getUpdates", payload, timeout=poll_timeout + 5).get("result") or []
            for update in updates:
                update_id = update.get("update_id")
                if isinstance(update_id, int):
                    next_offset = update_id + 1

                candidate = message_from_update(update)
                if not candidate or not same_chat(candidate, chat_id):
                    continue

                if candidate.get("message_id", 0) <= sent_message_id:
                    continue

                sender = candidate.get("from") or {}
                if sender.get("id") == bot_id:
                    continue

                text = message_text(candidate)
                if text:
                    emit_ok(text)
                    return 0

        emit_error(f"Telegram reply timed out after {timeout_seconds} seconds.")
        return 0
    except TelegramAgentError as error:
        emit_error(str(error))
        return 0
    except Exception as error:
        emit_error(f"Telegram agent failed: {error}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
