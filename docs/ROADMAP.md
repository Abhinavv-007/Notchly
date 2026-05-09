# Notchly Roadmap

Living document. Items grouped by impact + effort.

---

## Already shipped (v0.1.0)

- Modih Mail (envelope pill, left)
- Web notifications (bell pill, right) — Discord, Telegram, Instagram, WhatsApp, Gmail, Reddit, Slack
- Music-driven sliding pills
- File shelf with drag/drop, Quick Look, sharing
- HUD replacement (volume, brightness, battery, mic, downloads)
- Calendar + reminders
- Webcam mirror
- Polished onboarding + What's New screens
- Premium Modih Mail panel (skeleton loaders, sender avatars, copied flash, live refresh indicator)
- Auto-update popup disabled (deferred until appcast goes live)

---

## Quick wins (low effort, high polish)

### A. Modih Mail
- [ ] **Custom local-part picker.** Text field that lets the user pick `myname@modih.in` instead of random. Needs `local_part` body field on `POST /api/inbox` (verify modih.in API supports this; if yes, ~30 LOC client + UI change).
- [ ] **Domain selector.** If modih.in offers multiple domains (e.g. `@modih.in` / `@notchly.modih.in`), present a Picker.
- [ ] **Pinned senders.** Star a sender → always surface latest from them on top.
- [ ] **OTP auto-paste.** When a one-time code lands, copy it AND show a "Paste in active app" suggestion via `NSAccessibility`.
- [ ] **Inbox history list.** Last 5 mailboxes the user generated, one-tap restore (already half-supported via `MailboxPersistence`).

### B. Web notifications
- [ ] **Per-app badge color.** Use brand colour for each adapter (Discord purple, Slack green, etc.) instead of red dot for all.
- [ ] **"Snooze 1h" per app.** Suppress preview popups but keep aggregator counts.
- [ ] **Quiet hours.** Schedule (e.g. 22:00–08:00) in which no preview pops; only badge count updates.
- [ ] **More adapters.** Linear, Notion, Twitter/X, Bluesky, ChatGPT, Claude, Spotify-Wrapped-style ones.

### C. File shelf
- [ ] **Quick action buttons on hover.** Reveal in Finder, share, copy path, open with…
- [ ] **Smart auto-clean.** Items older than 7 days get a subtle "expires soon" dot; user toggles auto-purge.
- [ ] **Pinning.** Pin a file so auto-clean skips it.
- [ ] **Folder drop.** Drop a folder → shows count + total size badge.
- [ ] **Receive AirDrop directly into shelf.** Add AirDrop intent handler.

### D. Sliding pills / live activity
- [ ] **Lyrics ticker.** When music plays, slide the current lyric line across the pill (Apple Music + Spotify support via existing controllers).
- [ ] **Beat-synced glow.** Subtle pulse on the pill that matches the song BPM (use existing `MusicVisualizer`).
- [ ] **Now-playing artwork colour theming.** Already partially implemented (`playerColorTinting`) — extend to side-indicator pill background.

### E. Status bar / menu
- [ ] **Context menu actions on Notchly icon.** Right-click → quick-toggles for HUD, Calendar, Mirror, Add-ons.
- [ ] **Live count badges on the Notchly menu bar icon.** Optional: total unread count across mail+web in the icon.

### F. Onboarding / first-run
- [ ] **Permission walkthrough.** Explain each (Accessibility, Calendar, Camera, Apple Events) with a "Grant" button that opens the right pane.
- [ ] **Add-Ons sign-in chain.** After welcome, surface a "Sign into Gmail / Slack" carousel — single-step setup.

---

## Medium-effort features

### G. Pomodoro / focus timer
Tap the notch → start 25-min timer. Pill shows ring progress. Bell pings (or sneak-peek shows) on done. Implements: timer manager + ring view + sneak-peek hook. ~150 LOC.

### H. Clipboard history
Notchly observes `NSPasteboard`. Last 20 clips browsable from a new tab. Copy any → restore to pasteboard. Smart sensitive-content filter (skip 1Password / banking patterns). Privacy: opt-in.

### I. Workspace switcher
Mission-Control–style space switcher in the open notch. Read `NSScreen` + `CGSSpace` (private), show numbered cards for each space, tap to switch.

### J. Quick connect to AirPods / Bluetooth
Existing audio device list in HUD already partially exposed — add "Connect AirPods" tile.

### K. Screen recording mini-control
While recording (via macOS native), show timer + stop button in pill. Detect via `kAudioObjectPropertyRecordingState` or `screencapturekit`.

### L. Sneak peek for app installs / downloads
Detect new files in `~/Downloads/`, peek with size + open-with menu. Already partly there via `enableDownloadListener` + `DownloadIndicatorStyle`.

### M. Universal search
Cmd-Space alternative restricted to app-launching + Modih Mail OTP search + file-shelf items. Lightweight Spotlight clone scoped to Notchly content. Keyboard shortcut configurable.

### N. macOS native notifications routing
Route `UNUserNotificationCenter` deliveries through Notchly chrome instead of macOS default banner. Requires Apple notification grant + UNNotificationServiceExtension.

---

## Large bets

### O. Apple Developer ID signing + notarization
Set up DEV ID account → notarize releases → no more "right-click open" dance. Unlocks auto-update via Sparkle + appcast at `abhnv.in/notchly`.

### P. Sparkle appcast
Once signed: host `https://abhnv.in/notchly/appcast.xml`, generate `signEd25519` per release, re-enable `startingUpdater: true`, restore the "Check for updates" UI in About panel.

### Q. iOS / iPadOS companion app
- Push from iPhone → arrive in mac notch. Modih Mail OTPs surface on Mac before phone.
- Universal Clipboard supplement.
- Start Pomodoro on Mac, stop on iPhone.

### R. AI assistant pill
Claude / GPT prompt directly in the notch. Highlight any text on screen → Cmd-Shift-? → assistant response surfaces in pill. Model picker in settings (Anthropic key / OpenAI key in Keychain).

### S. Themes / personalization
Multiple notch themes (gradient packs), pill-shape variants, badge styles. Theme marketplace placeholder.

### T. Multi-window pop-out
Drag the open notch off the screen-top → it becomes a freestanding always-on-top window with the same content. Power-user mode.

---

## Bug / polish backlog (audit candidates)

- Audit `NotchlyDragCaptureWindow` parity in V3 → confirm V3's drop-detection works on edge cases.
- Audit memory: confirm all `Task` instances are stored in cancellable refs (sample of `MusicManager`, `WebNotificationAggregator`).
- `Localizable.xcstrings` cleanup of stale keys after Task 4 string changes.
- Replace the placeholder Sparkle public ED key with a generated one once signing exists.
- DMG: add custom background image + window layout (currently plain).
- Logo in onboarding: verify `Image("logo")` resolves correctly with new artwork (when ChatGPT-generated images land).
- Light mode: app is dark-mode-only; investigate light variants.
- Localization: 16 locales were inherited from boring.notch, but new add-on strings may not be translated. Either drop unused locales or run them through Crowdin.

---

## Out of scope (explicit nos)

- macOS < 14 support.
- Integration with apps the user explicitly removes (Discord etc. stay opt-in).
- Background polling on by default (battery cost). Only enable on user toggle.

---

## Sequencing recommendation

1. **Now:** ship v0.1.0 DMG (done).
2. **Next mini-release (v0.2.0):**
   - Custom Modih Mail local-part (verify API)
   - OTP auto-paste hint
   - Per-app brand colours for web notif badges
   - Hover actions on file shelf items
   - Updated app icon + screenshots from ChatGPT
3. **v0.3.0:** Pomodoro / focus timer + lyrics ticker.
4. **v0.4.0:** Clipboard history (opt-in).
5. **v1.0.0:** Apple DEV ID signing + notarization + Sparkle appcast live.

---

## How to suggest features

Open an issue at https://github.com/Abhinavv-007/Notchly/issues with the `enhancement` label. Include the user-facing scenario: what you want to do, what the notch should look like, what would tell you it succeeded.
