//
//  WebNotificationsPanel.swift
//  Notchly
//
//  Compact right-side notification strip shown inside the notch add-on
//  panel. Clicking an app icon opens a dedicated browser window for
//  that service so sign-in and message usage are practical.
//

import AppKit
import SwiftUI
import WebKit

struct WebNotificationsPanel: View {
    @ObservedObject var addonState: NotchAddonState = .shared
    @ObservedObject var webState: WebNotificationState = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            iconStrip
            appStatusGrid
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Web Notifications")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            if webState.totalUnreadCount > 0 {
                Text("\(webState.totalUnreadCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.red.opacity(0.85)))
                    .foregroundStyle(.white)
            }
        }
    }

    private var iconStrip: some View {
        let enabled = webState.orderedSnapshots.filter { $0.isEnabled }
        return HStack(spacing: 8) {
            if enabled.isEmpty {
                emptyState
            } else {
                ForEach(enabled, id: \.id) { snapshot in
                    WebNotificationAppIconView(snapshot: snapshot) {
                        openApp(snapshot.id)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var appStatusGrid: some View {
        let enabled = webState.orderedSnapshots.filter { $0.isEnabled }
        return LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 152, maximum: 220), spacing: 8, alignment: .top)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(enabled, id: \.id) { snapshot in
                Button(action: { openApp(snapshot.id) }) {
                    HStack(spacing: 10) {
                        WebNotificationBrandIcon(app: snapshot.id, size: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.id.displayName)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(statusLine(for: snapshot))
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if snapshot.unreadCount > 0 {
                            Text(snapshot.unreadCount > 99 ? "99+" : "\(snapshot.unreadCount)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.slash")
                .foregroundStyle(.gray)
            Text("Enable apps in Settings")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
    }

    private func openApp(_ id: WebNotificationAppID) {
        addonState.openWebNotifications()
        WebNotificationBrowserWindowController.shared.show(for: id)
    }

    private func statusLine(for snapshot: WebNotificationState.AppSnapshot) -> String {
        switch snapshot.login {
        case .signedIn:
            return snapshot.unreadCount == 0 ? "Signed in" : "\(snapshot.unreadCount) unread"
        case .signedOut:
            return "Sign in required"
        case .unknown:
            return "Checking session"
        }
    }
}

// MARK: - App Icon

struct WebNotificationAppIconView: View {
    let snapshot: WebNotificationState.AppSnapshot
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: { fire() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                snapshot.id.accentColor.opacity(isHovering ? 0.22 : 0.12),
                                snapshot.id.accentColor.opacity(isHovering ? 0.08 : 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(isHovering ? 0.18 : 0.08), lineWidth: 0.5)
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(isHovering ? 0.25 : 0.1), radius: isHovering ? 4 : 2, x: 0, y: 1)

                WebNotificationBrandIcon(app: snapshot.id, size: 20)

                badge
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : (isHovering ? 1.06 : 1.0))
        .help(snapshot.id.displayName)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isHovering = hovering
            }
        }
    }

    private func fire() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            isPressed = true
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isPressed = false
            }
            action()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if snapshot.unreadCount > 0 {
            let text = snapshot.unreadCount > 99 ? "99+" : "\(snapshot.unreadCount)"
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    Capsule()
                        .fill(Color.red)
                        .overlay(
                            Capsule().stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                        )
                )
                .offset(x: 10, y: -10)
        } else if snapshot.login == .signedOut {
            Circle()
                .fill(Color.gray)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.4))
                .frame(width: 6, height: 6)
                .offset(x: 10, y: -10)
        }
    }
}

// MARK: - Brand Icon

struct WebNotificationBrandIcon: View {
    let app: WebNotificationAppID
    var size: CGFloat = 20
    var showBackground: Bool = false

    var body: some View {
        if let url = app.officialIconURL {
            AsyncImage(url: url, transaction: Transaction(animation: .smooth(duration: 0.18))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                default:
                    fallbackIcon
                }
            }
            .frame(width: size, height: size)
        } else {
            fallbackIcon
                .frame(width: size, height: size)
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            if showBackground {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(app.accentColor.opacity(0.16))
            }

            Image(systemName: app.fallbackSymbol)
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Floating Browser Panel

@MainActor
final class WebNotificationBrowserWindowController: NSWindowController {
    static let shared = WebNotificationBrowserWindowController()

    private let defaultSize = NSSize(width: 1080, height: 780)
    private var hostingView: NSHostingView<WebNotificationBrowserRootView>?

    func show(for id: WebNotificationAppID) {
        guard let adapter = WebNotificationAdapters.adapter(for: id) else { return }

        let browserView = WebNotificationSessionManager.shared.browserWebView(for: adapter)
        if browserView.url == nil {
            WebNotificationSessionManager.shared.loadHomeInBrowser(for: adapter)
        }

        let rootView = WebNotificationBrowserRootView(appID: id, adapter: adapter)
        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let window = BrowserWindow(
                contentRect: NSRect(origin: .zero, size: defaultSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.backgroundColor = .windowBackgroundColor
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.minSize = NSSize(width: 860, height: 620)
            window.tabbingMode = .disallowed
            if #available(macOS 11.0, *) {
                window.toolbarStyle = .unifiedCompact
            }

            let hosting = NSHostingView(rootView: rootView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            window.contentView = hosting
            self.hostingView = hosting
            self.window = window
        }

        window?.title = "\(id.displayName)"
        positionWindow()
        let webView = WebNotificationSessionManager.shared.browserWebView(for: adapter)
        if webView.url == nil {
            WebNotificationSessionManager.shared.loadHomeInBrowser(for: adapter)
        }
        WebNotificationAggregator.shared.refreshApp(id)

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(webView)
        }
    }

    func closeWindow() {
        window?.close()
    }

    private func positionWindow() {
        guard let window else { return }
        let screen = NSScreen.screen(withUUID: NotchlyViewCoordinator.shared.selectedScreenUUID) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let width = max(defaultSize.width, window.frame.width)
        let height = max(defaultSize.height, window.frame.height)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.midY - height / 2
        let frame = NSRect(
            x: max(visibleFrame.minX + 16, min(x, visibleFrame.maxX - width - 16)),
            y: max(visibleFrame.minY + 24, min(y, visibleFrame.maxY - height - 24)),
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
    }
}

private final class BrowserWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct WebNotificationBrowserRootView: View {
    let appID: WebNotificationAppID
    let adapter: WebNotificationAppAdapter
    @ObservedObject private var webState = WebNotificationState.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                WebNotificationBrandIcon(app: appID, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appID.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                        .foregroundStyle(.white)
                }

                toolbarButton(systemName: "arrow.clockwise") {
                    WebNotificationSessionManager.shared.loadHomeInBrowser(for: adapter)
                    WebNotificationAggregator.shared.refreshApp(appID, forceLoadIfNeeded: true)
                }

                toolbarButton(systemName: "safari") {
                    NSWorkspace.shared.open(adapter.webURL)
                }

                toolbarButton(systemName: "xmark") {
                    WebNotificationBrowserWindowController.shared.closeWindow()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()
                .overlay(Color.white.opacity(0.08))

            EmbeddedWebView(adapter: adapter)
                .id(appID.rawValue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color.black.opacity(0.97))
    }

    private var unreadCount: Int {
        webState.snapshots[appID]?.unreadCount ?? 0
    }

    private var statusText: String {
        switch webState.snapshots[appID]?.login {
        case .signedIn:
            return "Signed in"
        case .signedOut:
            return "Sign in required"
        case .unknown, .none:
            return "Loading session"
        }
    }

    private func toolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}
