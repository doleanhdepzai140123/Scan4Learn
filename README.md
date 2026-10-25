# Scan4Learn

[![iOS build](https://github.com/doleanhdepzai140123/Scan4Learn/actions/workflows/ios.yml/badge.svg)](https://github.com/doleanhdepzai140123/Scan4Learn/actions/workflows/ios.yml)

**Scan4Learn** is a native SwiftUI study app for **iPhone (iOS 27+)** that turns any study material — a photo of your notebook, a PDF, or a Word document — into a personal learning library with AI-built study packs, FSRS-5 spaced repetition, and quizzes. Fully offline-first: your content and progress live on your device.

Six UI languages out of the box: **English · Tiếng Việt · 中文 · Русский · Français · Deutsch**.

## Features

| Area | What you get |
| --- | --- |
| **Import lessons** | Scan notebook pages with the system document scanner, pick photos, or import Word `.docx` and PDF files. On-device text recognition (Vision), editable text, and automatic subject suggestion from keywords in all six languages. |
| **AI study packs** | Sign in with ChatGPT (open-source OIDC flow — no API key needed) and generate summaries, flashcards and multiple-choice quizzes from a lesson in one tap, with a Thinking/Standard mode picker. A manual share-and-paste flow is always available as a fallback. |
| **FSRS-5 flashcards** | A state-of-the-art spaced-repetition scheduler with per-card stability and difficulty, four self-grading buttons with live interval previews, and a configurable target retention (80–95%). Pre-FSRS data migrates automatically. |
| **Quizzes** | Multiple-choice practice with per-question grading, explanations, and saved attempts per lesson. |
| **Custom subjects** | Organize lessons into folders — six built-ins plus as many custom subjects as you like, each with its own name, SF Symbol and accent color. Built-ins are editable and resettable. |
| **Weekly AI coaching** | Once signed in, the app sends the last 7 days of study statistics to ChatGPT every week and surfaces its coaching advice — weakest subjects, what to review, what to do next. |
| **Personalization** | Five color themes (forest, ocean, sun, rose, grape) with light/dark support, and an in-app language switch that applies instantly. |
| **Privacy** | Lessons, progress and credentials stay on the device. Tokens live in the Keychain. Nothing leaves the phone except content you explicitly share or send to ChatGPT. |

## Requirements

- **Xcode 27+** with the iOS 27 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An iPhone running **iOS 27 or later** for device builds (camera, document scanning, SideStore sideloading)
- Optional: a **ChatGPT Plus/Pro** account for AI study packs and weekly reports

## Getting started

```sh
git clone https://github.com/doleanhdepzai140123/Scan4Learn.git
cd Scan4Learn
xcodegen generate
open Scan4Learn.xcodeproj
```

Select the **Scan4Learn** scheme and an iPhone simulator, then Run. For a real device, set your own Team and Bundle ID under *Signing & Capabilities*. The only external dependency is [ZIPFoundation 0.9.19](https://github.com/weichsel/ZIPFoundation), used to read Word packages.

Run the test suite with **Product → Test**, or through CI.

### Windows-friendly sanity checks

The project is developed on Windows, so `check_project.py` verifies everything that does not need a Mac: project configuration, workflow shell syntax, Swift syntax parsing (via tree-sitter with `--swift-syntax`), and the string catalog itself — every key must carry all five translations with matching placeholders, every UI literal must exist in the catalog, and no entry may be dead.

```sh
python scripts/check_project.py
```

## Continuous integration

The **iOS · Build and test** workflow runs on every push to `main`, every PR, and on demand:

1. Generates the Xcode project with XcodeGen on an `xcode-27` runner.
2. Runs the unit tests on a single-display iPhone simulator (iOS 27).
3. Boots the app and captures a real screenshot.
4. Archives an **unsigned IPA** and uploads it with the screenshot as the `Scan4Learn-unsigned-needs-signing` artifact.

## Releases

Every tagged build is published automatically:

1. Push a tag (or run the workflow manually with a version input):

   ```sh
   git tag v0.3.0 && git push origin v0.3.0
   ```

2. Once CI passes, a GitHub release appears on the [Releases page](https://github.com/doleanhdepzai140123/Scan4Learn/releases) containing:
   - `Scan4Learn-<version>.ipa` — the unsigned app archive,
   - `Scan4Learn-iPhone.png` — a screenshot of the app running on the simulator.

**The IPA is unsigned and cannot be installed directly.** Sign it with [SideStore](https://sidestore.io/) (or any signing tool) first — no Apple certificate ever needs to live in this repository.

## How the ChatGPT integration works

Scan4Learn implements the [Sign in with ChatGPT open-source flow](https://developers.openai.com/siwc/token-sharing-open-source/sign-in):

- **OIDC + PKCE** in the system browser, with an **HTTP loopback redirect** on `127.0.0.1` per the contract (listener starts before the browser; only the port varies).
- **Dynamic client registration** — the first sign-in uses `dynamic_agent_client`; OpenAI issues a real `client_id` in the callback, which is persisted and reused.
- **Token handling** — access and refresh tokens are stored in the Keychain, refreshed transparently, and the ID token's issuer, audience, expiry and nonce are validated locally.
- **Inference** — the Responses API (`POST /v1/responses` with `store: false`, `stream: true`), with Thinking and Standard models resolved from the live `/v1/models` list. ChatGPT plan usage requires the `chatgpt.tokens.use.direct` scope granted by a Plus/Pro account.

No secrets, cookies, or API keys live in this repository. The app never reads your ChatGPT conversations.

## Project layout

```
.github/workflows/ios.yml    CI: test, screenshot, unsigned IPA
Scan4Learn/
  Models/                    Subjects, lessons, FSRS-5 scheduler, library store
  Services/                  Document reading (PDF/Word/OCR), ChatGPT auth + API,
                             weekly reports, icon catalog
  Views/                     SwiftUI screens and the shared design system
  Localizable.xcstrings      String catalog: English source + 5 translations
Scan4LearnTests/             Unit tests (logic, FSRS, auth, store, reports)
scripts/                     check_project.py, simulator selection for CI
project.yml                  XcodeGen project definition
```

## Testing

`Scan4LearnTests` covers subject suggestion in all six languages, the full FSRS-5 state machine (initial stability, growth, forgetting, same-day reviews, difficulty bounds, legacy migration), JSON import validation, the Word XML parser, library persistence and corruption protection, custom-subject lifecycle, settings persistence, the in-app language switch, the Sign in with ChatGPT contract (PKCE, authorization URL, JWT claims, loopback callback server, SSE parsing, Keychain) and the weekly-report statistics.

## Roadmap

- iCloud sync and library export/restore
- Shared lesson packs (export/import as a single file)
- Widget and App Intents support

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). By participating you agree to the [Code of Conduct](CONTRIBUTING.md#conduct).

## License

Released under the [MIT License](LICENSE).
