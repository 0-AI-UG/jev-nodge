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

The first launch opens setup inside the notch. Choose the assistant language and
voice activation mode, add one OpenRouter API key, then grant Microphone, Speech Recognition,
Accessibility, and optionally Screen Recording.

The selected assistant language controls speech recognition and the language of
Jev's spoken replies. Spoken replies use MOSS-TTS-Nano locally. Its multilingual model is downloaded
once on first use and then stays in the local cache. No speech-service account
or voice API key is required.

The microphone is off by default. Choose your voice shortcut in setup (default
Fn alone) to activate Jev Nodge temporarily, and press Escape to dismiss the
current surface. Always-on wake phrase detection is available as an explicit
opt-in in setup and from the menu bar.

Secrets are stored in macOS Keychain. Preferences use `UserDefaults`. Jev Nodge
does not write API keys to project files.

## Safety

Accessibility control is powerful. Shell and AppleScript workflows require a
spoken confirmation by default. Keep confirmations enabled, inspect custom
commands before using them, and do not use this preview on a Mac whose data you
cannot restore.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.
