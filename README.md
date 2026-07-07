<div align="center">
  <img src="docs/images/wordpop-preview.svg" alt="Bubble Corrector preview" width="100%" />

  # Bubble Corrector

  A native macOS menu bar spell assistant that turns spelling fixes into floating, clickable bubbles.

  [Download the DMG](https://github.com/Geltrax69/Bubble_Corrector/raw/main/dist/WordPop.dmg)
</div>

---

## What It Does

Bubble Corrector, built as **WordPop**, watches your typing system-wide. When it detects a misspelled word, it creates a floating correction bubble on your screen. Click the bubble and it bursts, then WordPop tries to replace the original misspelled word safely.

It is designed as a lightweight macOS utility:

- Menu bar app with no Dock clutter
- System-wide spelling detection using native macOS APIs
- Floating animated correction bubbles
- Multiple bubbles at the same time
- Bubble-to-bubble collision bounce
- Screen-edge bounce, including visible menu/Dock boundaries
- Click-to-burst correction flow
- Custom image or GIF bubble backgrounds
- Shape controls: Bubble, Circle, Rounded, Diamond, Star, and Random Curves
- Movement controls for speed and randomness
- Live preview in the control panel

## Download

The packaged app is included in this repository:

**[Download WordPop.dmg](https://github.com/Geltrax69/Bubble_Corrector/raw/main/dist/WordPop.dmg)**

After downloading:

1. Open `WordPop.dmg`.
2. Drag `WordPop.app` into `Applications`.
3. Launch WordPop.
4. Grant Accessibility permission when macOS asks.

> Note: this build is signed with an Apple Development certificate, not Developer ID notarized. On another Mac, Gatekeeper may ask you to allow it manually.

## Control Panel

<div align="center">
  <img src="docs/images/control-panel.png" alt="WordPop control panel" width="640" />
</div>

The control panel lets you customize:

- Bubble image or animated GIF
- Crop mode for large images
- Bubble size with live preview
- Movement speed from `0` to `1`
- Randomness from `0` to `1`
- Bubble shape
- Launch at login
- Enable/disable WordPop

## How Correction Works

WordPop uses macOS Accessibility APIs to remember where a misspelled word was typed. When you click a correction bubble, it attempts to re-select that original word and replace it.

This is intentionally safe:

- If WordPop can locate the original misspelled word, it replaces it.
- If the focused app hides the text field or refuses Accessibility range editing, WordPop skips replacement.
- It does **not** type at your current cursor position when the original word cannot be safely targeted.

That safety rule prevents bugs like inserting the correction into the wrong place after your cursor has moved.

## Current Limitation

Some apps, especially browser-based or Electron apps such as ChatGPT, WhatsApp Desktop, Slack-like apps, and some web editors, do not expose their editable text fields through macOS Accessibility in a way that supports safe old-word replacement.

In those apps WordPop can often show bubbles, but correction may be skipped if macOS does not provide a safe target.

Possible future solutions:

- Browser extension integration for web text editors
- App-specific adapters for Electron/web apps
- Optional clipboard-based correction mode
- A manual “copy corrected word” action

## Build From Source

Requirements:

- macOS 14+
- Xcode / Swift toolchain

Build the app:

```bash
swift build
```

Create the signed app bundle:

```bash
Scripts/build_wordpop_app.sh
```

Create the DMG:

```bash
Scripts/build_wordpop_dmg.sh
```

Generated files:

```text
dist/WordPop.app
dist/WordPop.dmg
```

## Project Structure

```text
WordPop/
  App/                 SwiftUI app entry point
  Managers/            Bubble and Accessibility management
  Models/              Settings model
  Services/            Keyboard monitor, replacement engine, spell checker
  Utilities/           Logging
  Views/               Menu bar UI, settings, bubble renderer
Scripts/
  build_wordpop_app.sh
  build_wordpop_dmg.sh
dist/
  WordPop.dmg
```

## Permissions

WordPop needs **Accessibility** permission because it monitors typing and asks macOS for focused text-field information.

Open:

```text
System Settings > Privacy & Security > Accessibility
```

Then enable `WordPop`.

## Status

Working:

- Native menu bar app
- DMG packaging
- Floating bubbles
- Custom image/GIF bubble background
- Live preview and controls
- Safe replacement when macOS exposes a text target
- Bubble collision and screen-edge bouncing

Still evolving:

- Universal correction inside apps that hide text fields from Accessibility
- Manual crop/position controls for uploaded images
- Notarized public distribution build

---

<div align="center">
  Made for macOS with SwiftUI, AppKit, Accessibility, CoreGraphics, and NSSpellChecker.
</div>
