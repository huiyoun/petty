#!/usr/bin/env python3

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path


class TelegramUserAgentError(Exception):
    pass


def emit_ok(message: str) -> None:
    print(json.dumps({"ok": True, "message": message}, ensure_ascii=False))


def emit_error(message: str) -> None:
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))


def emit_event(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def resolve_secret(value: str) -> str:
    if value.startswith("env:"):
        env_name = value[4:]
        resolved = os.environ.get(env_name, "")
        if not resolved:
            raise TelegramUserAgentError(f"Environment variable is empty: {env_name}")
        return resolved

    return value


def require_telethon():
    try:
        from telethon import TelegramClient, events
    except ModuleNotFoundError as error:
        raise TelegramUserAgentError(
            "Telethon is required. Install it with: python3 -m pip install --user telethon"
        ) from error

    return TelegramClient, events


def normalize_sender(value: str | None) -> str | None:
    if not value:
        return None

    return value.strip().lstrip("@").lower()


def normalize_chat(value: str) -> str:
    chat = value.strip()
    lowered = chat.lower()
    for prefix in ("telegram:", "tg:", "chat:"):
        if lowered.startswith(prefix):
            chat = chat[len(prefix):].strip()
            lowered = chat.lower()

    for prefix in ("https://t.me/", "http://t.me/", "t.me/"):
        if lowered.startswith(prefix):
            chat = chat[len(prefix):].strip("/")
            break

    return chat


def stable_entity_id(entity) -> str | None:
    chat_id = getattr(entity, "id", None)
    if chat_id is None:
        return None

    if getattr(entity, "megagroup", False) or getattr(entity, "broadcast", False):
        return f"-100{chat_id}"

    if getattr(entity, "is_group", False):
        return f"-{chat_id}"

    return str(chat_id)


def session_file_exists(session_path: Path) -> bool:
    if session_path.exists():
        return True

    return Path(f"{session_path}.session").exists()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="telegram-user-agent.py",
        description="Send Petty messages as a Telegram user session and wait for a reply.",
    )
    subparsers = parser.add_subparsers(dest="mode")

    setup = subparsers.add_parser("setup", help="Create or refresh an interactive Telegram user session.")
    setup.add_argument("api_id")
    setup.add_argument("api_hash")
    setup.add_argument("session")

    list_chats = subparsers.add_parser("list-chats", help="List chats visible to the Telegram user session.")
    list_chats.add_argument("api_id")
    list_chats.add_argument("api_hash")
    list_chats.add_argument("session")
    list_chats.add_argument("--limit", type=int, default=80)

    send = subparsers.add_parser("send", help="Send one message and wait for a reply.")
    send.add_argument("api_id")
    send.add_argument("api_hash")
    send.add_argument("session")
    send.add_argument("chat")
    send.add_argument("--timeout", type=int, default=int(os.environ.get("PETTY_TELEGRAM_TIMEOUT", "90")))
    send.add_argument("--settle", type=float, default=float(os.environ.get("PETTY_TELEGRAM_SETTLE", "3.0")))
    send.add_argument("--prefix", default=os.environ.get("PETTY_TELEGRAM_PREFIX", ""))
    send.add_argument("--reply-from", default=os.environ.get("PETTY_TELEGRAM_REPLY_FROM", ""))
    send.add_argument("message")

    bridge = subparsers.add_parser("bridge", help="Keep one Telegram session open for Petty.")
    bridge.add_argument("api_id")
    bridge.add_argument("api_hash")
    bridge.add_argument("session")
    bridge.add_argument("chat")
    bridge.add_argument("--prefix", default=os.environ.get("PETTY_TELEGRAM_PREFIX", ""))
    bridge.add_argument("--reply-from", default=os.environ.get("PETTY_TELEGRAM_REPLY_FROM", ""))

    args = parser.parse_args(argv[1:])
    if not args.mode:
        raise TelegramUserAgentError(
            "Usage: telegram-user-agent.py setup <api-id> <api-hash> <session> OR "
            "telegram-user-agent.py send <api-id> <api-hash> <session> <chat> [--timeout seconds] "
            "[--prefix text] [--reply-from username] message"
        )

    args.api_id = int(resolve_secret(args.api_id))
    args.api_hash = resolve_secret(args.api_hash)
    args.session = str(Path(resolve_secret(args.session)).expanduser())
    return args


async def setup_session(args: argparse.Namespace) -> str:
    TelegramClient, _ = require_telethon()
    Path(args.session).expanduser().parent.mkdir(parents=True, exist_ok=True)

    client = TelegramClient(args.session, args.api_id, args.api_hash)
    await client.start()
    me = await client.get_me()
    await client.disconnect()
    username = f"@{me.username}" if getattr(me, "username", None) else str(me.id)
    return f"Telegram user session is ready: {username}"


async def list_chats(args: argparse.Namespace) -> str:
    TelegramClient, _ = require_telethon()
    session_path = Path(args.session).expanduser()
    if not session_file_exists(session_path):
        raise TelegramUserAgentError(
            f"Telegram session not found: {session_path}. Run setup in Terminal first."
        )

    client = TelegramClient(str(session_path), args.api_id, args.api_hash)
    await client.connect()
    if not await client.is_user_authorized():
        await client.disconnect()
        raise TelegramUserAgentError("Telegram session is not authorized. Run setup in Terminal first.")

    rows: list[str] = []
    async for dialog in client.iter_dialogs(limit=args.limit):
        entity = dialog.entity
        title = dialog.name or getattr(entity, "title", None) or getattr(entity, "username", None) or "(untitled)"
        username = getattr(entity, "username", None)
        stable_id = stable_entity_id(entity) or "(unknown)"

        suffix = f" @{username}" if username else ""
        rows.append(f"{stable_id}\t{title}{suffix}")

    await client.disconnect()
    return "\n".join(rows) if rows else "No chats found."


async def resolve_chat_entity(client, chat: str):
    cleaned = normalize_chat(chat)
    candidates: list[object] = [cleaned]
    if cleaned.lstrip("-").isdigit():
        candidates.insert(0, int(cleaned))

    last_error: Exception | None = None
    for candidate in candidates:
        try:
            return await client.get_entity(candidate)
        except Exception as error:
            last_error = error

    target = cleaned.lstrip("@").lower()
    async for dialog in client.iter_dialogs():
        entity = dialog.entity
        values = [
            stable_entity_id(entity),
            str(getattr(entity, "id", "")),
            dialog.name,
            getattr(entity, "title", None),
            getattr(entity, "username", None),
        ]
        normalized = {str(value).lstrip("@").lower() for value in values if value}
        if target in normalized:
            return entity

    detail = f": {last_error}" if last_error else ""
    raise TelegramUserAgentError(
        f'Telegram chat not found: "{chat}"{detail}. '
        "Run list-chats and use the leftmost chat id, usually -100... for a group."
    )


async def send_and_wait(args: argparse.Namespace) -> str:
    TelegramClient, events = require_telethon()
    session_path = Path(args.session).expanduser()
    if not session_file_exists(session_path):
        raise TelegramUserAgentError(
            f"Telegram session not found: {session_path}. Run setup in Terminal first."
        )

    client = TelegramClient(str(session_path), args.api_id, args.api_hash)
    await client.connect()
    if not await client.is_user_authorized():
        await client.disconnect()
        raise TelegramUserAgentError("Telegram session is not authorized. Run setup in Terminal first.")

    entity = await resolve_chat_entity(client, args.chat)
    me = await client.get_me()
    if getattr(entity, "id", None) == getattr(me, "id", None):
        raise TelegramUserAgentError(
            "Telegram chat resolved to your own account, so Telegram would send it to Saved Messages. "
            "Use the OpenClaw bot username, the OpenClaw bot DM row from list-chats, or the group id."
        )

    reply_from = normalize_sender(args.reply_from)
    loop = asyncio.get_running_loop()
    future: asyncio.Future[str] = loop.create_future()
    settle_task: asyncio.Task | None = None
    sent_message_id: int | None = None
    replies: dict[int, str] = {}

    async def handler(event) -> None:
        nonlocal sent_message_id, settle_task
        if future.done() or event.out:
            return

        message_id = event.message.id
        if sent_message_id is not None and message_id <= sent_message_id:
            return

        text = (event.raw_text or "").strip()
        if not text:
            return

        if reply_from:
            sender = await event.get_sender()
            username = normalize_sender(getattr(sender, "username", None))
            sender_id = str(getattr(sender, "id", ""))
            if reply_from not in {username, sender_id}:
                return

        if settle_task:
            settle_task.cancel()

        replies[message_id] = text

        async def resolve_after_settle() -> None:
            try:
                await asyncio.sleep(max(args.settle, 0))
                if not future.done():
                    ordered = [
                        replies[key]
                        for key in sorted(replies)
                        if replies[key].strip()
                    ]
                    future.set_result("\n\n".join(ordered))
            except asyncio.CancelledError:
                pass

        settle_task = asyncio.create_task(resolve_after_settle())

    client.add_event_handler(handler, events.NewMessage(chats=entity))
    client.add_event_handler(handler, events.MessageEdited(chats=entity))
    sent = await client.send_message(entity, f"{args.prefix}{args.message}")
    sent_message_id = sent.id

    try:
        return await asyncio.wait_for(future, timeout=args.timeout)
    finally:
        client.remove_event_handler(handler)
        if settle_task:
            settle_task.cancel()
        await client.disconnect()


async def bridge_session(args: argparse.Namespace) -> None:
    TelegramClient, events = require_telethon()
    session_path = Path(args.session).expanduser()
    if not session_file_exists(session_path):
        raise TelegramUserAgentError(
            f"Telegram session not found: {session_path}. Run setup in Terminal first."
        )

    client = TelegramClient(str(session_path), args.api_id, args.api_hash)
    await client.connect()
    if not await client.is_user_authorized():
        await client.disconnect()
        raise TelegramUserAgentError("Telegram session is not authorized. Run setup in Terminal first.")

    entity = await resolve_chat_entity(client, args.chat)
    me = await client.get_me()
    if getattr(entity, "id", None) == getattr(me, "id", None):
        await client.disconnect()
        raise TelegramUserAgentError(
            "Telegram chat resolved to your own account, so Telegram would send it to Saved Messages. "
            "Use the OpenClaw bot username, the OpenClaw bot DM row from list-chats, or the group id."
        )

    reply_from = normalize_sender(args.reply_from)

    async def sender_is_allowed(event) -> bool:
        if not reply_from:
            return True

        sender = await event.get_sender()
        username = normalize_sender(getattr(sender, "username", None))
        sender_id = str(getattr(sender, "id", ""))
        return reply_from in {username, sender_id}

    async def emit_incoming(event, edited: bool) -> None:
        if event.out:
            return

        text = (event.raw_text or "").strip()
        if not text:
            return

        if not await sender_is_allowed(event):
            return

        emit_event(
            {
                "ok": True,
                "type": "message",
                "message": text,
                "message_id": event.message.id,
                "edited": edited,
            }
        )

    async def new_message_handler(event) -> None:
        await emit_incoming(event, edited=False)

    async def edited_message_handler(event) -> None:
        await emit_incoming(event, edited=True)

    client.add_event_handler(new_message_handler, events.NewMessage(chats=entity))
    client.add_event_handler(edited_message_handler, events.MessageEdited(chats=entity))
    emit_event({"ok": True, "type": "ready"})

    try:
        while True:
            line = await asyncio.to_thread(sys.stdin.readline)
            if not line:
                break

            line = line.strip()
            if not line:
                continue

            try:
                payload = json.loads(line)
                message = str(payload.get("message", "")).strip()
            except json.JSONDecodeError:
                message = line

            if not message:
                continue

            try:
                sent = await client.send_message(entity, f"{args.prefix}{message}")
                emit_event({"ok": True, "type": "sent", "message_id": sent.id})
            except Exception as error:
                emit_event({"ok": False, "type": "send-error", "error": str(error)})
    finally:
        client.remove_event_handler(new_message_handler)
        client.remove_event_handler(edited_message_handler)
        await client.disconnect()


async def run(argv: list[str]) -> int:
    try:
        args = parse_args(argv)
        if args.mode == "setup":
            emit_ok(await setup_session(args))
        elif args.mode == "list-chats":
            emit_ok(await list_chats(args))
        elif args.mode == "bridge":
            await bridge_session(args)
        else:
            emit_ok(await send_and_wait(args))
        return 0
    except TelegramUserAgentError as error:
        emit_error(str(error))
        return 0
    except asyncio.TimeoutError:
        emit_error("Telegram reply timed out.")
        return 0
    except Exception as error:
        emit_error(f"Telegram user agent failed: {error}")
        return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run(sys.argv)))
