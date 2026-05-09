# Installing Notchly

## Option 1 — DMG (recommended)

1. Go to [Notchly releases](https://github.com/Abhinavv-007/Notchly/releases/latest).
2. Download `Notchly.dmg`.
3. Double-click `Notchly.dmg` to mount it.
4. Drag **Notchly** to the **Applications** folder shortcut in the open window.
5. Eject the DMG.
6. Open **Applications**, find **Notchly**.

### First launch (unsigned dev build)

Notchly is currently distributed as an unsigned developer build. macOS will refuse to open it on first launch unless you explicitly allow it:

- **Right-click** Notchly.app → **Open** → confirm in the dialog.

(Or: System Settings → Privacy & Security → scroll to "Notchly was blocked" → **Open Anyway**.)

You only do this once. Subsequent launches open normally.

### Permissions

Notchly asks for these on first launch — grant each one:

- **Accessibility** — required to position the window over the notch and to read media keys.
- **Calendar** — required for the calendar widget (skip if you don't use it).
- **Camera** — required for the mirror feature (skip if you don't use it).
- **Apple Events / Spotify / Music** — required to read currently playing track from Spotify or Apple Music.

If you skip a permission, the corresponding feature stays dark. You can grant later from System Settings → Privacy & Security.

## Option 2 — Build from source

Requires Xcode 15+ and macOS 14 SDK.

```bash
git clone https://github.com/Abhinavv-007/Notchly.git
cd Notchly
xcodebuild -project Notchly.xcodeproj -scheme Notchly \
  -configuration Release build CODE_SIGNING_ALLOWED=NO
```

The built app is at:
```
~/Library/Developer/Xcode/DerivedData/Notchly-*/Build/Products/Release/Notchly.app
```

Copy it into `/Applications/`:
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/Notchly-*/Build/Products/Release/Notchly.app /Applications/
xattr -dr com.apple.quarantine /Applications/Notchly.app
open /Applications/Notchly.app
```

## Uninstall

```bash
osascript -e 'tell application "Notchly" to quit'
rm -rf /Applications/Notchly.app
defaults delete in.abhnv.notchly
rm -rf ~/Library/Application\ Support/boringNotch
```

(The `boringNotch` directory in Application Support is the legacy V2 path retained intentionally for shelf state — clearing it removes saved shelf items.)

## Add-Ons setup

After install:

1. Open Notchly → **Settings** (Cmd+,).
2. Open **Add-Ons** tab.
3. Toggle **Modih Mail** on, paste an API key if you have one (free inbox works without).
4. Toggle **Web Notifications** on. For each app you want notifications from (Gmail, Discord, Slack, etc.) click **Sign in** and complete the login in the embedded webview.

Web notifications stay live as long as Notchly runs.

## Troubleshooting

| Symptom | Fix |
|---|---|
| App won't open: "Notchly is damaged" | Run `xattr -dr com.apple.quarantine /Applications/Notchly.app`, then reopen. |
| Notch position wrong on external display | Settings → General → Preferred Screen — pick the right one. |
| Music live activity not showing | Make sure Notchly has Apple Events permission for Spotify/Music in Privacy settings. |
| Bell pill always 0 unread | Sign into the web apps in Add-Ons settings; reopen each one once to warm the session. |
| Modih Mail says "rate limited" | Free inbox has request limits. Paste an API key in Add-Ons settings. |

## Reporting bugs

Open an issue at [github.com/Abhinavv-007/Notchly/issues](https://github.com/Abhinavv-007/Notchly/issues).

Include:
- macOS version (`sw_vers`)
- Mac model (`sysctl -n machdep.cpu.brand_string` + screen)
- Notchly version (Settings → About)
- What you did, what happened, what you expected
- Console.app log filtered to `Notchly` if you have one
