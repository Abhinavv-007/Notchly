<div align="center">
  <img src="Notchly/Assets.xcassets/logo2.imageset/Notchly icon.png" alt="Notchly" width="160" />

  # Notchly

  **Turn your MacBook notch into a control surface.**

  Media · File shelf · Mail · Web notifications — all in the space you already ignore.

  <p>
    <img src="https://img.shields.io/badge/macOS-14%20Sonoma%2B-000000?style=for-the-badge&logo=apple" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/SwiftUI-Native-FA7343?style=for-the-badge&logo=swift" alt="SwiftUI" />
    <img src="https://img.shields.io/badge/build-passing-2ea44f?style=for-the-badge" alt="build" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=for-the-badge" alt="license" /></a>
  </p>

  <p>
    <a href="https://github.com/Abhinavv-007/Notchly/releases/latest"><img src="https://img.shields.io/badge/⬇%20Download%20Notchly-Latest%20Release-1f6feb?style=for-the-badge" alt="Download" height="44" /></a>
  </p>

  <sub>By <a href="https://abhnv.in"><b>Abhinav Raj</b></a> · <a href="https://abhnv.me">abhnv.me</a> · <a href="https://modih.in">modih.in</a> · <a href="https://clex.in">clex.in</a></sub>
</div>

---

## Why Notchly

Your MacBook notch is dead space. Notchly fills it with the things you actually reach for:

- **🎵 Media live activity** — album art, scrubber, controls. Pill widens when music plays, returns when it stops.
- **📁 File shelf** — drag a file onto the notch, it lives there until you need it. Quick Look, share, drag back out.
- **✉️ Modih Mail** — a temporary inbox (powered by [modih.in](https://modih.in)) one click away, left of the notch.
- **🔔 Web notifications** — Discord, Telegram, Instagram, WhatsApp, Gmail, Reddit, Slack — one bell, right of the notch.
- **🌗 Live HUD** — volume, brightness, battery, mic, downloads — reskinned for the notch.
- **📅 Calendar + reminders** — one tap to today's agenda.
- **⚙️ Notch utility** — sliding pills, themed visualizer, hover gestures, multi-display.

## Sliding Pills

When music plays, the closed notch widens for the live activity. Notchly adds two flanking pills — envelope (left) for mail, bell (right) for notifications. They slide outward with the pill and return when music stops. No janky overlap, no fixed-position chrome.

```
   ┌──────────┐                      ┌─ envelope ─┐  ┌─── pill ────┐  ┌─ bell ─┐
   │   notch  │   ←  music starts  →
   └──────────┘                      └────────────┘  └─────────────┘  └────────┘
```

## Quick install

1. Download `Notchly.dmg` from the [latest release](https://github.com/Abhinavv-007/Notchly/releases/latest).
2. Open it and drag **Notchly** into **Applications**.
3. First launch: Right-click the app → **Open** (it's unsigned; macOS asks once).
4. Grant Accessibility + Calendar + Camera permissions when prompted.

Detailed steps in [INSTALL.md](INSTALL.md).

## Web notifications setup

Notchly's bell pill talks to web apps through embedded WebKit sessions. Sign in once per app:

1. Open **Settings** → **Add-Ons** → **Web Notifications**.
2. Pick an app (Gmail, Slack, etc.) → **Sign in**.
3. Session stays warm; new notifications surface as previews around the notch.

Background polling is **off by default** to keep energy use low. Toggle it in Add-Ons settings if you want it on.

## Modih Mail

The envelope pill opens a [modih.in](https://modih.in) temporary inbox. Free addresses work without a key — paste an API key in **Settings → Add-Ons → Modih Mail** for the developer plan with no expiry.

## Build from source

```bash
git clone https://github.com/Abhinavv-007/Notchly.git
cd Notchly
open Notchly.xcodeproj
```

Or terminal-only:

```bash
xcodebuild -project Notchly.xcodeproj -scheme Notchly -configuration Release \
  build CODE_SIGNING_ALLOWED=NO
```

Output `.app` lands at `~/Library/Developer/Xcode/DerivedData/Notchly-*/Build/Products/Release/Notchly.app`.

## Stack

| | |
|---|---|
| **UI** | SwiftUI + AppKit |
| **Web** | WebKit |
| **Media** | MediaRemote + Spotify / Apple Music / YouTube Music adapters |
| **Updater** | Sparkle |
| **Storage** | `Defaults` (Sindre) + Keychain |
| **Calendar** | EventKit |

## Status

- macOS 14 Sonoma+
- M-series + Intel
- Multi-display (notch detection per screen)
- Unsigned dev builds; codesigning + notarization on the roadmap.

## Roadmap

- Apple Developer ID signing + notarization
- Auto-update via Sparkle (appcast at `abhnv.in/notchly`)
- More web notification adapters
- Localization expansion (Crowdin-driven)

## Credits

Notchly stands on the shoulders of the open-source [`boring.notch`](https://github.com/TheBoredTeam/boring.notch) — thanks to the original community for the notch-utility groundwork. Notchly is a separate fork by Abhinav Raj with the AddOns layer, branding, and bug fixes layered on top.

## License

Apache 2.0 — see [LICENSE](LICENSE).

Third-party notices in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

## Author

**Abhinav Raj** · [abhnv.in](https://abhnv.in) · [abhnv.me](https://abhnv.me) · [linkedin.com/in/abhnv07](https://www.linkedin.com/in/abhnv07/)

Other projects: [modih.in](https://modih.in) · [clex.in](https://clex.in)
