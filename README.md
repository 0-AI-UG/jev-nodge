# Jev Nodge

Jev Nodge is a small, open-source macOS assistant that lives in the display notch.
It listens locally, uses TypeSafe Jev through OpenRouter to choose grounded
actions, controls visible Mac applications through Accessibility and OCR, and
uses a generative model for conversational answers.

## Current scope

The first release is an experimental developer preview for macOS 14 or newer.
It supports app and website launch, keyboard commands, typing, named UI clicks,
media and volume control, screenshots, configurable AppleScript or shell
workflows, and spoken AI answers. It does not claim unattended reliability for
arbitrary destructive tasks.

## Develop

Requirements: Xcode Command Line Tools, Swift 6.2+, and pnpm 10.

```sh
pnpm dev
pnpm check
pnpm install:app
pnpm update:app
```

The first launch opens setup inside the notch. Choose a wake name, add one
OpenRouter API key, select a voice, then grant Microphone, Speech Recognition,
Accessibility, and optionally Screen Recording.

Choose any wake name in setup and say “Hey <name>” before a command. Press
Option-Space to arm or hide Jev Nodge without a wake phrase, and Escape to dismiss
the current surface.

Secrets are stored in macOS Keychain. Preferences use `UserDefaults`. Jev Nodge
does not write API keys to project files.

## Safety

Accessibility control is powerful. Shell and AppleScript workflows require a
spoken confirmation by default. Keep confirmations enabled, inspect custom
commands before using them, and do not use this preview on a Mac whose data you
cannot restore.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.
