# Contributing to Scan4Learn

Thanks for your interest in improving Scan4Learn! This document explains how to set up, work with the codebase, and send changes.

## Development setup

1. Install [Xcode 27+](https://developer.apple.com/xcode/) with the iOS 27 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Fork and clone the repository, then generate the Xcode project:

   ```sh
   xcodegen generate
   open Scan4Learn.xcodeproj
   ```

3. Never edit `Scan4Learn.xcodeproj` by hand — it is generated from `project.yml` on every CI run.

## Ground rules

- **English is the project language.** Code, comments, commit messages, issues and pull requests are written in English. The string catalog is English-sourced; keep the other five translations (Vietnamese, Simplified Chinese, Russian, French, German) in sync.
- **Every user-facing string lives in `Localizable.xcstrings`.** If you add a UI string, add the key with all five translations — `check_project.py` enforces this, along with placeholder parity.
- **Keep the app offline-first.** Nothing should leave the device except content the user explicitly shares or sends to ChatGPT.
- **Match the existing style.** SwiftUI views stay declarative and compact; logic lives in `Models/` and `Services/` and is covered by unit tests.

## Testing

Run the full local check before every push — it is exactly what CI relies on for everything a Windows machine can verify:

```sh
python scripts/check_project.py
```

On a Mac, also run the unit tests with **Product → Test**. New features should come with tests; bug fixes should come with a test that would have caught the bug.

## Submitting changes

1. Create a topic branch from `main`.
2. Make your change with focused commits (`feat: …`, `fix: …`, `docs: …`).
3. Run `python scripts/check_project.py` and the test suite.
4. Open a pull request describing what changed and why. CI must pass.

## Conduct

Be kind, be patient, and assume good intent. Harassment or dismissive behavior of any kind is not acceptable in this project's spaces.
