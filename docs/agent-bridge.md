# Telegram Agent Bridge

This document explains the recommended way to connect Petty to an existing AI agent through Telegram.

이 문서는 Petty를 기존 AI 에이전트에 Telegram으로 연결하는 권장 방식을 설명합니다.

Petty does not create a new agent. It sends your message to the Telegram chat where your agent already lives, then displays the incoming agent messages in the macOS pet UI.

Petty는 새로운 에이전트를 만들지 않습니다. 사용자의 메시지를 에이전트가 이미 있는 Telegram 채팅으로 보내고, 들어오는 에이전트 메시지를 macOS 펫 UI에 표시합니다.

## Recommended Mode

Use the Telegram user relay.

권장 방식은 Telegram 사용자 릴레이입니다.

The user relay sends messages from your own Telegram account. This is more reliable than a bot-token relay when the target agent is also a Telegram bot, because many bots do not receive or respond to messages sent by another bot.

사용자 릴레이는 사용자의 Telegram 계정에서 메시지를 보냅니다. 대상 에이전트도 Telegram 봇인 경우, 봇 토큰 릴레이보다 안정적입니다. 많은 봇은 다른 봇이 보낸 메시지를 받거나 응답하지 않기 때문입니다.

## Configuration File

Petty stores its app configuration here:

Petty 앱 설정은 여기에 저장됩니다:

```text
~/Library/Application Support/Petty/config.json
```

Petty stores local chat history here:

Petty의 로컬 대화 기록은 여기에 저장됩니다:

```text
~/Library/Application Support/Petty/history.json
```

The easiest way to write the Telegram configuration is through the Petty menu bar item: `Settings...` -> `Telegram` -> `Save`.

Telegram 설정을 저장하는 가장 쉬운 방법은 macOS 메뉴바의 Petty 아이콘에서 `Settings...` -> `Telegram` -> `Save`를 사용하는 것입니다.

## Setup Steps

### 1. Create a Telegram API App

Open `https://my.telegram.org/apps`, log in, create an app, and copy the `api_id` and `api_hash`.

`https://my.telegram.org/apps`를 열고 로그인한 뒤 앱을 생성하고 `api_id`와 `api_hash`를 복사합니다.

The API Hash is a secret. Do not commit it.

API Hash는 비밀값입니다. 커밋하지 마세요.

### 2. Install Telethon

Install Telethon in a virtual environment:

가상환경에 Telethon을 설치합니다:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

Using a virtual environment avoids macOS system Python restrictions.

가상환경을 사용하면 macOS 시스템 Python 제한을 피할 수 있습니다.

### 3. Create a Telegram Session

Run setup once:

setup 명령을 한 번 실행합니다:

```sh
.venv/bin/python scripts/telegram-user-agent.py setup <api-id> <api-hash> ~/.petty/telegram-user
```

Telegram may ask for your phone number, login code, and two-step password. After login, the script writes a local session file.

Telegram이 전화번호, 로그인 코드, 2단계 인증 비밀번호를 물어볼 수 있습니다. 로그인 후 스크립트가 로컬 세션 파일을 저장합니다.

The session file is sensitive. Do not commit `~/.petty/telegram-user.session`.

세션 파일은 민감합니다. `~/.petty/telegram-user.session`을 커밋하지 마세요.

### 4. Find the Target Chat ID

List visible Telegram chats:

보이는 Telegram 채팅 목록을 출력합니다:

```sh
.venv/bin/python scripts/telegram-user-agent.py list-chats <api-id> <api-hash> ~/.petty/telegram-user
```

Use the leftmost numeric value for the target bot DM or group.

대상 봇 DM 또는 그룹 행의 가장 왼쪽 숫자를 사용하세요.

For groups and supergroups, the ID usually starts with `-100`. If Petty sends messages to Saved Messages, you probably used your own user ID instead of the target chat ID.

그룹과 슈퍼그룹 ID는 보통 `-100`으로 시작합니다. Petty 메시지가 Saved Messages로 간다면 대상 채팅 ID 대신 자기 자신의 사용자 ID를 사용했을 가능성이 큽니다.

### 5. Configure Petty

Open the Petty menu bar icon and choose `Settings...`.

macOS 메뉴바의 Petty 아이콘을 누르고 `Settings...`를 선택합니다.

Choose `Telegram` mode and enter:

`Telegram` 모드를 선택하고 아래 값을 입력합니다:

- `API ID`
- `API Hash`
- `Session Path`, usually `~/.petty/telegram-user`
- `Chat ID` from `list-chats`
- `Reply From`, optional but recommended for groups

`Reply From` can be the agent bot username or numeric ID. It helps Petty filter incoming messages when the group has other traffic.

`Reply From`에는 에이전트 봇 username 또는 숫자 ID를 넣을 수 있습니다. 그룹에 다른 메시지가 섞일 때 Petty가 들어오는 메시지를 필터링하는 데 도움이 됩니다.

Click `Save`, then click the pet and send a test message.

`Save`를 누른 뒤 펫을 클릭해서 테스트 메시지를 보내세요.

## Runtime Behavior

When Telegram mode is configured, Petty starts:

Telegram 모드가 설정되면 Petty는 아래 bridge를 실행합니다:

```text
scripts/telegram-user-agent.py bridge
```

The bridge stays open while Petty is running. Petty writes outgoing messages to the bridge, and the bridge prints incoming Telegram messages back to Petty.

bridge는 Petty가 실행되는 동안 계속 열려 있습니다. Petty는 보낼 메시지를 bridge에 쓰고, bridge는 Telegram에서 들어오는 메시지를 다시 Petty에 출력합니다.

This lets Petty show multiple agent messages for one request, including command execution messages, status updates, and final answers.

이 방식 덕분에 Petty는 하나의 요청에 대해 명령 실행 메시지, 상태 업데이트, 최종 답변처럼 여러 개의 에이전트 메시지를 표시할 수 있습니다.

## Troubleshooting

`Telethon is required`

`Telethon is required`가 표시되는 경우

Install Telethon in the project virtual environment:

프로젝트 가상환경에 Telethon을 설치하세요:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

Message goes to Saved Messages

메시지가 Saved Messages로 가는 경우

Run `list-chats` again and use the target bot or group row. Do not use your own private user ID.

`list-chats`를 다시 실행하고 대상 봇 또는 그룹 행을 사용하세요. 자기 자신의 개인 사용자 ID를 사용하면 안 됩니다.

Group was upgraded to a supergroup

그룹이 슈퍼그룹으로 변경된 경우

Run `list-chats` again and update the Chat ID in Petty Settings. The new ID usually starts with `-100`.

`list-chats`를 다시 실행하고 Petty Settings의 Chat ID를 새 값으로 바꾸세요. 새 ID는 보통 `-100`으로 시작합니다.

Petty sends messages but no replies appear

Petty가 메시지를 보내지만 답변이 표시되지 않는 경우

First confirm that the agent replies inside Telegram. If the group has other traffic, set `Reply From` to the agent bot username or numeric ID.

먼저 에이전트가 Telegram 안에서 실제로 답장하는지 확인하세요. 그룹에 다른 메시지가 섞인다면 `Reply From`에 에이전트 봇 username 또는 숫자 ID를 넣으세요.

## Security Rules

Do not commit Telegram API hashes, session files, bot tokens, `.env`, `config.json`, or `history.json`.

Telegram API Hash, 세션 파일, 봇 토큰, `.env`, `config.json`, `history.json`은 커밋하지 마세요.

Petty stores conversation history locally only, and it is not encrypted in the MVP.

Petty의 대화 기록은 로컬에만 저장되며, MVP에서는 암호화되어 있지 않습니다.

Petty does not execute scripts from pet packs. Codex-compatible pet packs are read as JSON metadata and image assets.

Petty는 pet pack 안의 스크립트를 실행하지 않습니다. Codex-compatible pet pack은 JSON 메타데이터와 이미지 asset으로만 읽습니다.

## Other Bridge Modes

Local command, HTTP, SSH, and older bot-token wrappers may exist in the repository for development or experiments, but Telegram user relay is the recommended path for this MVP.

로컬 command, HTTP, SSH, 예전 bot-token wrapper가 개발이나 실험용으로 repo에 남아 있을 수 있지만, 이 MVP에서 권장하는 방식은 Telegram 사용자 릴레이입니다.
