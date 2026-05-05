# Petty Architecture

Petty is a small macOS desktop frontend for an AI agent the user already runs.

## Components

- Floating Pet Window: a transparent, borderless AppKit panel that hosts the SwiftUI pet view. It stays above regular windows and can be dragged around the screen.
- Chat Panel: a compact floating AppKit panel that hosts the SwiftUI chat UI. It appears near the pet when the user clicks the pet.
- Speech Bubble Panel: a transparent, non-interactive AppKit panel that appears above the pet for short agent replies and errors.
- Pet State Manager: `AppModel` owns the visible chat messages, speech bubble text, and the current `PetState`.
- Agent Bridge: `AgentBridge` defines the app-to-agent boundary. `LocalCommandAgentBridge` supports synchronous command wrappers. `TelegramUserAgentBridge` keeps one Telegram user relay process open while Petty is running so multi-message agent replies can arrive asynchronously.
- Settings Window: a menu bar-accessible SwiftUI settings surface for custom commands, Telegram user relay values, and local pet pack selection.

## MVP Flow

1. The user launches Petty.
2. `AppDelegate` creates the shared `AppModel`, floating pet window, and chat panel.
3. The user clicks the pet to toggle the chat panel.
4. The user sends a message.
5. `AppModel` switches the pet to `thinking` and calls the configured bridge.
6. For a local command, the bridge returns one JSON response on stdout.
7. For Telegram user relay, Petty writes outgoing messages to the persistent bridge process and receives incoming Telegram events over stdout.
8. Petty displays the response, updates the speech bubble, and switches the pet to `success`, or displays an error and switches to `error`.
