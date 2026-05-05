# Petty

Petty is a tiny floating pixel pet for macOS.

It sits on your desktop, opens a compact chat panel when clicked, and forwards your messages to a local or remote personal AI agent.

Petty does not implement a new AI agent. It is a lightweight desktop interface for agents you already run, such as OpenClaw, Hermes, Codex CLI, Gemini CLI, or your own scripts.

Petty can reuse Codex-compatible pet designs as-is. If you already have a Codex pet pack with `pet.json` and `spritesheet.webp`, Petty can scan it from `~/.codex/pets` and render the same pixel pet on your desktop.

## Status

Petty is an experimental early MVP. It is useful as a hackable macOS interface for a personal agent, but it is not packaged, notarized, sandboxed, or App Store-ready yet.

## MVP

- Transparent floating pet window
- Always-on-top behavior
- Drag-to-move pet
- Click-to-toggle compact chat panel
- Local command agent bridge
- JSON stdout response parsing
- Pet states: `idle`, `thinking`, `success`, `error`
- Short pet speech bubbles for agent responses and errors
- Codex-compatible pet pack rendering from `~/.codex/pets`, so existing Codex pet designs can be reused without conversion
- macOS menu bar item for chat, settings, config reload, and quit
- Telegram user relay with a persistent bridge process for multi-message agent replies
- Local chat history persistence with a menu bar clear action

## Agent Configuration

Petty creates this file on first launch when it does not exist:

```text
~/Library/Application Support/Petty/config.json
```

Chat history is stored locally at:

```text
~/Library/Application Support/Petty/history.json
```

```json
{
  "agent": {
    "command": "/absolute/path/to/petty-agent",
    "arguments": []
  }
}
```

The command receives the user message as its final argument and must print:

```json
{ "ok": true, "message": "Agent response" }
```

or:

```json
{ "ok": false, "error": "Agent connection failed" }
```

If no config exists, Petty uses the bundled mock agent.

You can edit this from the menu bar: click the Petty paw icon, then choose `Settings...`.
Petty accepts either an absolute executable path or a command name found in common shell paths such as `/opt/homebrew/bin` and `/usr/local/bin`.

For the Telegram user relay, choose `Telegram` in Settings and fill in:

- `API ID` and `API Hash` from `https://my.telegram.org/apps`
- `Chat ID from list-chats, usually -100... for a group`
- optional `Reply From username or id` for the OpenClaw bot

Settings generates the command configuration for you. Use `Copy Setup Command` once to create the Telegram session, then use `Copy Chat List Command` to find the numeric chat ID. Use the leftmost value from the OpenClaw bot DM or OpenClaw group row. For OpenClaw in a group, this is the group or supergroup ID, usually starting with `-100`; it is not your personal Telegram user ID. If you enter your own user ID, Telegram sends the message to Saved Messages.

Example for a local agent command:

```json
{
  "agent": {
    "command": "openclaw",
    "arguments": ["chat"]
  }
}
```

For OpenClaw running on a Tailscale-connected server, use the included SSH wrapper:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/openclaw-ssh-agent.sh",
    "arguments": ["user@server.example.ts.net", "main"]
  }
}
```

If the server needs an absolute OpenClaw path, add it as the third argument:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/openclaw-ssh-agent.sh",
    "arguments": ["user@server.example.ts.net", "main", "/usr/local/bin/openclaw"]
  }
}
```

If SSH is not practical but the server is reachable over LAN, Tailscale, or another private route, run a small HTTP bridge on the server and use the included HTTP wrapper:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/http-agent.sh",
    "arguments": ["http://agent-host.local:8787/chat"]
  }
}
```

The HTTP bridge receives `POST /chat` with `{ "message": "..." }` and should return `{ "ok": true, "message": "..." }`.

For different networks without SSH or Tailscale, use Telegram as the relay. The recommended path is the Telegram user relay because it sends messages from your own Telegram account, so an agent bot receives them like normal human messages:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
.venv/bin/python scripts/telegram-user-agent.py setup <api-id> <api-hash> ~/.petty/telegram-user
.venv/bin/python scripts/telegram-user-agent.py list-chats <api-id> <api-hash> ~/.petty/telegram-user
```

Then choose `Telegram` in Petty Settings, enter the API values and chat ID, and save.

At runtime, Petty keeps one Telegram user bridge process open while the app is running. This lets Petty receive every later OpenClaw message, including intermediate command/status messages and final results, instead of only waiting for one synchronous reply.

The older bot relay is still available through Custom command mode. Put your existing agent bot and a dedicated Petty bot in a small private group, then configure Petty with the Petty bot token and group chat ID:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/telegram-agent.py",
    "arguments": [
      "env:PETTY_TELEGRAM_BOT_TOKEN",
      "-1000000000000",
      "--timeout",
      "90"
    ]
  }
}
```

If the existing agent is another Telegram bot, enable Telegram's bot-to-bot communication mode in BotFather when needed so it can receive messages sent by the Petty bot.

If you prefer editing JSON directly, the Telegram user relay config looks like this:

```json
{
  "agent": {
    "command": "/path/to/petty/.venv/bin/python",
    "arguments": [
      "/path/to/petty/scripts/telegram-user-agent.py",
      "send",
      "<api-id>",
      "<api-hash>",
      "~/.petty/telegram-user",
      "-1000000000000",
      "--timeout",
      "90",
      "--reply-from",
      "OpenClawBotUsername"
    ]
  }
}
```

Set `petId` to choose a specific local pet pack:

```json
{
  "agent": {
    "command": "/absolute/path/to/petty-agent",
    "arguments": []
  },
  "petId": "miku"
}
```

## Chat Controls

- `Enter`: send
- `Shift` + `Enter`: insert a new line
- `Command` + `Enter`: send from the Send button shortcut

## Menu Bar

When Petty is running, a paw icon stays in the macOS menu bar.

- `Open Chat`: opens the chat panel near the pet
- `Settings...`: opens agent and pet settings
- `Reload Config`: reloads `config.json` from disk
- `Clear Chat History`: deletes local `history.json` and resets the chat view
- `Quit Petty`: exits the app

## Run Locally

```sh
xcodebuild -project Petty.xcodeproj -scheme Petty -configuration Debug -derivedDataPath DerivedData build
killall Petty
open "DerivedData/Build/Products/Debug/Petty.app"
```

## Known Limitations

- No notarized release build yet.
- No sandbox entitlement configuration yet.
- Telegram user relay requires a local Telethon session.
- Telegram bridge reconnect/backoff is basic and should be hardened.
- Conversation history is local-only and not encrypted.
- Third-party pet packs are not bundled.

## Assets

Petty is designed to use Codex-compatible pet packs directly. A pet design made for Codex pets can be reused in Petty without changing the artwork, as long as the pack includes the expected `pet.json` and `spritesheet.webp` files.

Petty scans `~/.codex/pets/<pet-id>/pet.json` and `spritesheet.webp`. The MVP expects the Codex-compatible `1536x1872` atlas with `192x208` cells. See [docs/pet-pack-format.md](docs/pet-pack-format.md).

Petty does not bundle third-party pet assets by default. Imported pet packs remain under their original creators' rights and licenses.

## Build

```sh
xcodebuild -project Petty.xcodeproj -scheme Petty -configuration Debug build
```

## License

MIT
