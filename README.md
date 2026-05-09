# Notchly

Notchly is a macOS notch utility by **Abhinav Raj** that turns the MacBook notch into a compact control surface for media, files, mail, and web notification previews.

- Creator: Abhinav Raj — [linkedin.com/in/abhnv07](https://www.linkedin.com/in/abhnv07/)
- Personal: [abhnv.in](https://abhnv.in) · [abhnv.me](https://abhnv.me)
- Projects: [modih.in](https://modih.in) · [clex.in](https://clex.in)
- Platform: macOS 14 Sonoma or later
- Stack: SwiftUI, AppKit, WebKit

## Features

- Notch expansion with a native macOS-feeling animation.
- Media live activity with album art, controls, and visualizer.
- File shelf with drag/drop, Quick Look, and sharing.
- Modih Mail (envelope pill, left of the closed notch).
- Web notifications (bell pill, right of the closed notch) for Discord, Telegram, Instagram, WhatsApp, Gmail, Reddit, and Slack.
- Music-driven sliding pills: when music plays, the closed notch widens and the side pills slide outward with it.
- Calendar, reminders, mirror, HUD replacement, and notch customization.

## Building

```bash
open Notchly.xcodeproj
```

Or:

```bash
xcodebuild -project Notchly.xcodeproj -scheme Notchly -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## License

See [LICENSE](./LICENSE).
