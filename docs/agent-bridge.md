# Agent Bridge

Petty MVP talks to an agent through a local command.

## Configuration

Petty reads this file when it exists. On first launch, Petty creates a default config pointing at the bundled mock agent when the file is missing.

```text
~/Library/Application Support/Petty/config.json
```

Petty stores local chat history separately:

```text
~/Library/Application Support/Petty/history.json
```

This file can be deleted from the macOS menu bar item with `Clear Chat History`.

Example:

```json
{
  "agent": {
    "command": "/absolute/path/to/petty-agent",
    "arguments": []
  }
}
```

## OpenClaw over Tailscale SSH

When OpenClaw runs on another machine in your Tailnet, point Petty at the SSH wrapper:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/openclaw-ssh-agent.sh",
    "arguments": ["user@server.example.ts.net", "main"]
  }
}
```

If `openclaw` is not on the server user's non-interactive SSH `PATH`, pass the remote path as a third argument:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/openclaw-ssh-agent.sh",
    "arguments": ["user@server.example.ts.net", "main", "/usr/local/bin/openclaw"]
  }
}
```

Petty appends the user's chat text as the final argument, so the wrapper runs this on the server:

```text
openclaw agent --local --json --agent main -m "<message>"
```

Requirements:

- The Mac can reach the server over Tailscale.
- SSH key login works from the Mac to the server without an interactive password prompt.
- `openclaw` is installed on the server and available in the server user's login environment.

If the server uses a custom OpenClaw path, set `OPENCLAW_BIN` inside the wrapper or create a small server-side shell alias/script.

The same values can be edited in Petty's menu bar settings window.

If config creation fails, the app still uses the bundled `mock-agent.sh` script as an in-memory fallback.

## HTTP Bridge over LAN or Tailscale

If SSH key login is not available, run a small HTTP bridge on the server and point Petty at `http-agent.sh`:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/http-agent.sh",
    "arguments": ["http://agent-host.local:8787/chat"]
  }
}
```

Petty appends the user's chat text as the final argument, and `http-agent.sh` sends this request:

```http
POST /chat
Content-Type: application/json

{ "message": "<message>" }
```

The HTTP server can return Petty's native response shape:

```json
{
  "ok": true,
  "message": "OpenClaw reply"
}
```

It can also return `reply`, `response`, `output`, `text`, or `content`; the wrapper normalizes those fields into Petty's `{ "ok": true, "message": "..." }` contract.

For same Wi-Fi, the server must listen on the LAN interface and the Mac must be able to reach that host and port. For Tailscale, a MagicDNS host such as `http://agent-host:8787/chat` works when firewall rules allow it.

## Legacy Telegram Bot Relay

For different networks without Tailscale or SSH, Petty can send messages through Telegram. The older bot-token relay works best with a small private group that contains:

- your existing OpenClaw or personal agent Telegram bot
- a dedicated Petty Telegram bot

Configure Petty with the Telegram wrapper:

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

Petty appends the user's chat text as the final argument. The wrapper:

- sends the message to `chat_id` with `sendMessage`
- polls the same bot token with `getUpdates`
- returns the first later message from the same chat that was not sent by the Petty bot itself

To avoid putting the bot token directly in config, the first argument can reference an environment variable:

```json
{
  "agent": {
    "command": "/path/to/petty/scripts/telegram-agent.py",
    "arguments": [
      "env:PETTY_TELEGRAM_BOT_TOKEN",
      "-1000000000000"
    ]
  }
}
```

If the existing agent is another Telegram bot, enable Telegram's bot-to-bot communication mode for the relevant bot in BotFather when needed. Without that, Telegram may not deliver bot-authored messages to the agent bot. If the agent listens through a user account or a server-side Telegram client, this limitation does not apply in the same way.

The wrapper uses Telegram Bot API methods `sendMessage` and `getUpdates`. If the Petty bot has an active webhook, `getUpdates` will fail; use a dedicated bot token for Petty polling.

If Telegram returns `Bad Request: group chat was upgraded to a supergroup chat`, the configured group id is the old pre-upgrade id. The wrapper retries once with Telegram's `migrate_to_chat_id` response parameter, but you should update Petty's config to the new supergroup id from the latest `getUpdates` output.

### Telegram User Relay

If the target agent is a Telegram bot that cannot see messages sent by the Petty bot, use `telegram-user-agent.py` instead. This sends the message from a Telegram user session, so the agent bot receives it the same way it receives a human message.

The easiest setup is through Petty's menu bar settings window:

1. Choose `Settings...`.
2. Select `Telegram`.
3. Enter `API ID` and `API Hash` from `https://my.telegram.org/apps`.
4. Click `Copy Setup Command`, run it once in Terminal, and finish Telegram login.
5. Click `Copy Chat List Command`, run it in Terminal, and copy the numeric group/chat ID.
6. Put that ID into `Chat ID from list-chats`, optionally set `Reply From username or id`, then save.

Use the leftmost value from the OpenClaw bot DM or OpenClaw group row in `list-chats`. For a group or supergroup this usually starts with `-100`. Do not use the private chat id from Bot API `getUpdates`; that can identify your own Telegram user/private chat, not the OpenClaw target. If the chat resolves to your own account, Telegram sends the message to Saved Messages.

Install the dependency in the project virtual environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

Create a Telegram API app at `https://my.telegram.org/apps`, then run setup once in Terminal:

```sh
.venv/bin/python scripts/telegram-user-agent.py setup <api-id> <api-hash> ~/.petty/telegram-user
```

After login succeeds, configure Petty:

If the group title contains symbols or cannot be resolved by name, list visible chats and use the numeric id:

```sh
.venv/bin/python scripts/telegram-user-agent.py list-chats <api-id> <api-hash> ~/.petty/telegram-user
```

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

`chat` can be a group title, username, or id that the logged-in Telegram account can resolve. Numeric IDs are the most reliable. `--reply-from` is optional, but recommended when the group has other traffic.

Petty stores Telegram user relay settings in this `send` shape for compatibility with the settings UI. At runtime, the app detects this configuration and starts `telegram-user-agent.py bridge ...` as a persistent child process. The bridge stays open while Petty runs, accepts outgoing messages on stdin, and emits incoming Telegram messages on stdout. This is important for modern OpenClaw flows that send intermediate command/status messages before the final result.

The script still supports one-shot `send` mode for manual testing:

```sh
.venv/bin/python scripts/telegram-user-agent.py send <api-id> <api-hash> ~/.petty/telegram-user -1000000000000 "hello"
```

## Command Contract

Petty passes the user message as the final command argument:

```text
/absolute/path/to/petty-agent "today's status?"
```

The `command` field may be an absolute path or a command name. Command names are resolved from the app environment plus common CLI install paths, including `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, and `/sbin`.

Example:

```json
{
  "agent": {
    "command": "openclaw",
    "arguments": ["chat"]
  }
}
```

The command must write one JSON object to stdout.

Success:

```json
{
  "ok": true,
  "message": "Everything is normal."
}
```

Failure:

```json
{
  "ok": false,
  "error": "Agent connection failed"
}
```

## Security Rules

- Petty only executes the command path explicitly configured by the user or the bundled mock script.
- Telegram bot tokens are secrets and should not be committed to the repository.
- Telegram API hashes and `.session` files are secrets and should not be committed to the repository.
- `history.json` can contain private conversation text and should not be committed to the repository.
- Petty does not execute shell commands from downloaded pet packs.
- Imported pet packs are out of MVP scope; future support should read only image and JSON metadata by default.
- Conversation history is persisted locally only.

## Known Limitations

- Custom command wrappers are synchronous and return one response.
- Telegram user relay supports asynchronous multi-message replies, but reconnect/backoff behavior is still basic.
- Petty is not notarized or sandboxed yet.
- Petty does not encrypt local conversation history.
