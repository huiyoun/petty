# Petty

Petty is a tiny floating pixel pet for macOS.

It sits on your desktop, opens a compact chat panel when clicked, and sends your messages to the AI agent you already use.

Petty does not implement a new AI agent. The main goal is to give your existing agent, such as OpenClaw, a cute macOS desktop interface through Telegram.

Petty can reuse Codex-compatible pet designs as-is. If you already have a Codex pet pack with `pet.json` and `spritesheet.webp`, Petty can scan it from `~/.codex/pets` and render the same pixel pet on your desktop.

## English Guide

### Status

Petty is an experimental early MVP. It works as a hackable macOS interface for a personal agent, but it is not packaged, notarized, sandboxed, or App Store-ready yet.

### MVP Features

- Transparent floating pet window
- Always-on-top behavior
- Drag-to-move pet
- Click-to-toggle compact chat panel
- Telegram user relay for OpenClaw or another Telegram-connected agent
- Persistent Telegram bridge while Petty is running, so intermediate command/status messages can appear too
- Pet states: `idle`, `thinking`, `success`, `error`
- Short speech bubbles above the pet for agent replies and errors
- Local chat history persistence
- macOS menu bar item for chat, settings, config reload, history clear, and quit
- Codex-compatible pet pack rendering from `~/.codex/pets`

### Quick Start

Install Xcode command line tools if this is your first time building a macOS project:

```sh
xcode-select --install
```

Clone the repository:

```sh
git clone https://github.com/huiyoun/petty.git
cd petty
```

Build and install Petty into your user Applications folder:

```sh
scripts/install-app.sh
```

Open the app:

```sh
open ~/Applications/Petty.app
```

Petty runs as a menu bar accessory app. It may not appear in the Dock. Use the Petty menu bar icon to open Settings or quit the app.

### Connect with Telegram

Telegram is the recommended bridge for Petty. It works well when your AI agent is already connected to Telegram, or when your agent runs on another server that your Mac cannot reach directly.

Petty uses a Telegram user session, not a Telegram bot token, for the recommended setup. That means messages are sent from your own Telegram account, so an agent bot can receive them like normal human messages.

#### What You Need

- A macOS machine with Xcode command line tools available
- Telegram account
- Telegram API ID and API Hash from `https://my.telegram.org/apps`
- An OpenClaw bot, personal agent bot, or group chat that is already visible in your Telegram account
- Python virtual environment with Telethon installed

#### Step 1. Create a Telegram API App

Go to `https://my.telegram.org/apps`, log in with your Telegram phone number, and create an app. Copy the `api_id` and `api_hash`.

These values identify your Telegram client app. Treat the API Hash as a secret.

#### Step 2. Install Telethon

Install Telethon in the project virtual environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

Do not install Python packages into the system Python if macOS says the environment is externally managed. A virtual environment avoids that problem.

#### Step 3. Create Your Telegram Session

Run setup once:

```sh
.venv/bin/python scripts/telegram-user-agent.py setup <api-id> <api-hash> ~/.petty/telegram-user
```

Telegram will ask for your phone number, login code, and possibly your two-step password. When it finishes, Petty can reuse the saved session file.

The session file is sensitive. Do not commit files like `~/.petty/telegram-user.session`.

#### Step 4. Find the Correct Chat ID

List the chats visible to your Telegram account:

```sh
.venv/bin/python scripts/telegram-user-agent.py list-chats <api-id> <api-hash> ~/.petty/telegram-user
```

Use the leftmost numeric value from the target bot DM or target group row.

Groups and supergroups usually start with `-100`. Do not use your own private user ID unless you really want to send messages to yourself. If Petty messages go to Saved Messages, the Chat ID is probably wrong.

#### Step 5. Configure Petty

Open the Petty menu bar icon and choose `Settings...`.

Choose `Telegram` mode, then fill in:

- `API ID`: the value from `my.telegram.org`
- `API Hash`: the value from `my.telegram.org`
- `Session Path`: `~/.petty/telegram-user`
- `Chat ID`: the numeric ID from `list-chats`
- `Reply From`: optional, but recommended when using a group with an agent bot

`Reply From` can be a bot username, user username, or numeric ID. In a noisy group, it helps Petty decide which incoming messages should be displayed as agent replies.

Click `Save`. Petty writes the generated configuration to:

```text
~/Library/Application Support/Petty/config.json
```

#### Step 6. Test It

Click the pet, type a message, and send it. Petty should send the message through Telegram and show incoming agent messages in the chat panel and speech bubble.

While Petty is running, it keeps a Telegram bridge process open. This is important for newer OpenClaw flows because the agent may send command/status messages before the final answer.

### How It Works

Petty starts `scripts/telegram-user-agent.py bridge` internally when Telegram mode is configured. The bridge reads outgoing messages from Petty and prints incoming Telegram messages back to Petty.

This is different from a simple one-shot command. A persistent bridge can receive every later agent message while the app is open.

### Troubleshooting

`Telethon is required`

Install Telethon inside the project virtual environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

Messages go to Saved Messages

The Chat ID is probably your own user ID. Run `list-chats` again and use the leftmost numeric value for the actual bot DM or group.

The group was upgraded to a supergroup

Run `list-chats` again and update Petty with the new group ID. Supergroup IDs usually start with `-100`.

Petty sends a message, but no reply appears

Check that the target agent replies in Telegram first. If you are using a group, set `Reply From` to the agent bot username or numeric ID.

### Local Data and Secrets

Petty stores config here:

```text
~/Library/Application Support/Petty/config.json
```

Petty stores local chat history here:

```text
~/Library/Application Support/Petty/history.json
```

Do not commit Telegram API hashes, session files, `config.json`, `history.json`, `.env`, or bot tokens.

### Menu Bar

When Petty is running, a paw icon stays in the macOS menu bar.

- `Open Chat`: open the chat panel near the pet
- `Settings...`: open Telegram and pet settings
- `Reload Config`: reload `config.json`
- `Clear Chat History`: delete local `history.json` and reset the chat view
- `Quit Petty`: exit the app

### Chat Controls

- `Enter`: send
- `Shift` + `Enter`: insert a new line
- `Command` + `Enter`: send from the Send button shortcut
- Pencil icon next to the chat title: rename the chat panel without opening Settings

### Codex-Compatible Pets

Petty is designed to use Codex-compatible pet packs directly. A pet design made for Codex pets can be reused in Petty without changing the artwork, as long as the pack includes the expected `pet.json` and `spritesheet.webp` files.

Petty scans `~/.codex/pets/<pet-id>/pet.json` and `spritesheet.webp`. The MVP expects the Codex-compatible `1536x1872` atlas with `192x208` cells. See [docs/pet-pack-format.md](docs/pet-pack-format.md).

To force Petty to use the built-in pixel pet instead of a Codex-compatible pet pack, choose `Normal (built-in)` in Settings or set `petId` to `normal`.

Petty does not bundle third-party pet assets by default. Imported pet packs remain under their original creators' rights and licenses.

### Build

```sh
xcodebuild -project Petty.xcodeproj -scheme Petty -configuration Debug build
```

### Other Bridge Modes

Local command and HTTP wrappers exist for development and experiments, but Telegram is the recommended setup for this MVP.

## 한국어 안내

Petty는 macOS 화면 위에 떠 있는 작은 픽셀 펫입니다.

평소에는 데스크톱 위에 있다가, 클릭하면 작은 채팅창을 열고, 사용자가 이미 쓰고 있는 AI 에이전트에게 메시지를 전달합니다.

Petty는 새로운 AI 에이전트를 만드는 앱이 아닙니다. 핵심 목적은 OpenClaw 같은 기존 에이전트를 Telegram을 통해 macOS 데스크톱에서 귀엽게 사용할 수 있게 만드는 것입니다.

Petty는 Codex-compatible 펫 디자인을 그대로 사용할 수 있습니다. 이미 `pet.json`과 `spritesheet.webp`가 있는 Codex pet pack이 있다면, Petty가 `~/.codex/pets`에서 읽어서 같은 픽셀 펫을 데스크톱에 표시할 수 있습니다.

### 상태

Petty는 아직 실험적인 초기 MVP입니다. 개인 에이전트를 위한 해킹 가능한 macOS 인터페이스로는 동작하지만, 아직 정식 패키징, notarization, sandbox, App Store 배포는 준비되어 있지 않습니다.

### MVP 기능

- 투명한 floating pet window
- 항상 다른 창 위에 떠 있는 동작
- 마우스로 펫 위치 이동
- 펫 클릭으로 compact chat panel 열고 닫기
- OpenClaw 또는 Telegram에 연결된 다른 에이전트를 위한 Telegram 사용자 릴레이
- Petty가 켜져 있는 동안 유지되는 Telegram bridge
- 펫 상태: `idle`, `thinking`, `success`, `error`
- 에이전트 답변과 에러를 펫 위 말풍선으로 짧게 표시
- 로컬 대화 기록 저장
- 채팅, 설정, 설정 재로드, 기록 삭제, 종료를 위한 macOS 메뉴바 아이콘
- `~/.codex/pets`에서 Codex-compatible pet pack 렌더링

### 빠른 시작

macOS 프로젝트를 처음 빌드한다면 Xcode command line tools를 먼저 설치합니다:

```sh
xcode-select --install
```

레포를 clone합니다:

```sh
git clone https://github.com/huiyoun/petty.git
cd petty
```

Petty를 빌드해서 사용자 Applications 폴더에 설치합니다:

```sh
scripts/install-app.sh
```

앱을 실행합니다:

```sh
open ~/Applications/Petty.app
```

Petty는 메뉴바 앱처럼 실행됩니다. Dock에는 보이지 않을 수 있습니다. 설정을 열거나 앱을 끄려면 macOS 상단바의 Petty 아이콘을 사용하세요.

### Telegram으로 연결하기

Telegram은 Petty에서 권장하는 연결 방식입니다. AI 에이전트가 이미 Telegram에 연결되어 있거나, 에이전트가 Mac에서 직접 접근하기 어려운 다른 서버에서 실행될 때 특히 편합니다.

권장 설정에서는 Telegram 봇 토큰이 아니라 Telegram 사용자 세션을 사용합니다. 그래서 메시지가 사용자의 Telegram 계정에서 보내지고, 에이전트 봇은 사람이 보낸 일반 메시지처럼 받을 수 있습니다.

#### 필요한 것

- Xcode command line tools가 준비된 macOS 기기
- Telegram 계정
- `https://my.telegram.org/apps`에서 발급받은 Telegram API ID와 API Hash
- 사용자의 Telegram 계정에서 이미 보이는 OpenClaw 봇, 개인 에이전트 봇, 또는 그룹 채팅
- Telethon이 설치된 Python 가상환경

#### 1단계. Telegram API 앱 만들기

`https://my.telegram.org/apps`에 접속해서 Telegram 전화번호로 로그인한 뒤 앱을 하나 만드세요. 생성 후 `api_id`와 `api_hash`를 복사합니다.

이 값들은 사용자의 Telegram 클라이언트 앱을 식별합니다. API Hash는 비밀값으로 취급하세요.

#### 2단계. Telethon 설치하기

프로젝트 가상환경에 Telethon을 설치합니다:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

macOS에서 Python 환경이 externally managed라고 나오면 시스템 Python에 직접 설치하지 마세요. 가상환경을 쓰면 이 문제를 피할 수 있습니다.

#### 3단계. Telegram 세션 만들기

아래 setup 명령을 한 번 실행합니다:

```sh
.venv/bin/python scripts/telegram-user-agent.py setup <api-id> <api-hash> ~/.petty/telegram-user
```

Telegram이 전화번호, 로그인 코드, 2단계 인증 비밀번호를 물어볼 수 있습니다. 완료되면 Petty가 저장된 세션 파일을 재사용합니다.

세션 파일은 민감한 파일입니다. `~/.petty/telegram-user.session` 같은 파일을 Git에 커밋하지 마세요.

#### 4단계. 올바른 Chat ID 찾기

사용자의 Telegram 계정에서 보이는 채팅 목록을 출력합니다:

```sh
.venv/bin/python scripts/telegram-user-agent.py list-chats <api-id> <api-hash> ~/.petty/telegram-user
```

대상 봇 DM 또는 대상 그룹 행의 가장 왼쪽 숫자를 사용하세요.

그룹과 슈퍼그룹 ID는 보통 `-100`으로 시작합니다. 자기 자신에게 보내려는 것이 아니라면 개인 사용자 ID를 쓰면 안 됩니다. Petty 메시지가 Saved Messages로 간다면 Chat ID가 잘못된 경우가 많습니다.

#### 5단계. Petty 설정하기

macOS 상단바의 Petty 아이콘을 누르고 `Settings...`를 엽니다.

`Telegram` 모드를 선택한 뒤 아래 값을 입력합니다:

- `API ID`: `my.telegram.org`에서 받은 값
- `API Hash`: `my.telegram.org`에서 받은 값
- `Session Path`: `~/.petty/telegram-user`
- `Chat ID`: `list-chats`에서 확인한 숫자 ID
- `Reply From`: 그룹에서 에이전트 봇을 쓸 때 권장되는 선택 항목

`Reply From`에는 봇 username, 사용자 username, 숫자 ID를 넣을 수 있습니다. 여러 메시지가 섞이는 그룹에서는 Petty가 어떤 메시지를 에이전트 답변으로 표시할지 판단하는 데 도움이 됩니다.

`Save`를 누르면 Petty가 생성한 설정을 아래 위치에 저장합니다:

```text
~/Library/Application Support/Petty/config.json
```

#### 6단계. 테스트하기

펫을 클릭하고 메시지를 입력한 뒤 전송하세요. Petty가 Telegram을 통해 메시지를 보내고, 에이전트에게서 오는 답변을 채팅창과 말풍선에 표시해야 합니다.

Petty가 실행 중일 때는 Telegram bridge 프로세스를 계속 열어둡니다. 최신 OpenClaw처럼 최종 답변 전에 명령 실행 상태나 중간 메시지를 보내는 흐름에서 이 방식이 중요합니다.

### 동작 방식

Telegram 모드가 설정되면 Petty는 내부적으로 `scripts/telegram-user-agent.py bridge`를 실행합니다. bridge는 Petty에서 보내는 메시지를 읽고, Telegram에서 들어오는 메시지를 다시 Petty로 전달합니다.

이 방식은 단발성 명령 실행과 다릅니다. 지속적으로 열린 bridge는 앱이 켜져 있는 동안 나중에 도착하는 에이전트 메시지도 계속 받을 수 있습니다.

### 문제 해결

`Telethon is required`가 표시되는 경우

프로젝트 가상환경 안에 Telethon을 설치하세요:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install telethon
```

메시지가 Saved Messages로 가는 경우

Chat ID가 자기 자신의 사용자 ID일 가능성이 큽니다. `list-chats`를 다시 실행하고 실제 봇 DM 또는 그룹 행의 가장 왼쪽 숫자를 사용하세요.

그룹이 슈퍼그룹으로 변경된 경우

`list-chats`를 다시 실행한 뒤 새 그룹 ID로 Petty 설정을 업데이트하세요. 슈퍼그룹 ID는 보통 `-100`으로 시작합니다.

Petty가 메시지를 보내지만 답변이 보이지 않는 경우

먼저 대상 에이전트가 Telegram에서 실제로 답장하는지 확인하세요. 그룹을 사용 중이라면 `Reply From`에 에이전트 봇 username 또는 숫자 ID를 넣으세요.

### 로컬 데이터와 비밀값

Petty 설정은 여기에 저장됩니다:

```text
~/Library/Application Support/Petty/config.json
```

Petty의 로컬 대화 기록은 여기에 저장됩니다:

```text
~/Library/Application Support/Petty/history.json
```

Telegram API Hash, 세션 파일, `config.json`, `history.json`, `.env`, 봇 토큰은 커밋하지 마세요.

### 메뉴바

Petty가 실행 중이면 macOS 메뉴바에 발바닥 아이콘이 남아 있습니다.

- `Open Chat`: 펫 근처에 채팅 패널 열기
- `Settings...`: Telegram과 펫 설정 열기
- `Reload Config`: `config.json` 다시 읽기
- `Clear Chat History`: 로컬 `history.json` 삭제 후 채팅창 초기화
- `Quit Petty`: 앱 종료

### 채팅 조작

- `Enter`: 전송
- `Shift` + `Enter`: 줄바꿈
- `Command` + `Enter`: Send 버튼 단축키로 전송
- 채팅 제목 옆 연필 아이콘: Settings를 열지 않고 채팅창 이름 변경

### Codex-Compatible Pets

Petty는 Codex-compatible pet pack을 직접 사용하는 방향으로 설계되어 있습니다. `pet.json`과 `spritesheet.webp`가 있는 Codex 펫 디자인이라면 아트워크를 바꾸지 않고 Petty에서 재사용할 수 있습니다.

Petty는 `~/.codex/pets/<pet-id>/pet.json`과 `spritesheet.webp`를 읽습니다. MVP는 Codex-compatible `1536x1872` atlas와 `192x208` cell 구조를 기대합니다. 자세한 내용은 [docs/pet-pack-format.md](docs/pet-pack-format.md)를 참고하세요.

Codex-compatible pet pack 대신 내장 픽셀 펫을 강제로 쓰려면 Settings에서 `Normal (built-in)`을 선택하거나 `petId`를 `normal`로 설정하면 됩니다.

Petty는 기본적으로 제3자 pet asset을 포함하지 않습니다. 사용자가 가져온 pet pack은 원 제작자의 권리와 라이선스를 따릅니다.

### 빌드

```sh
xcodebuild -project Petty.xcodeproj -scheme Petty -configuration Debug build
```

### 다른 Bridge 방식

로컬 command와 HTTP wrapper는 개발과 실험을 위해 남아 있지만, 이 MVP에서 권장하는 연결 방식은 Telegram입니다.

## License

MIT
