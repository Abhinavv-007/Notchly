//
//  WebNotificationSessionManager.swift
//  Notchly
//
//  Lazy WKWebView host for every web notification adapter. Phase A ships
//  an empty shell that compiles and exposes the eventual public API
//  (`webView(for:)`, `signOut(from:)`, `refreshAll()`) without actually
//  allocating WKWebViews.
//
//  Phase C fills this in with a real `WKProcessPool`-sharing,
//  `WKWebsiteDataStore`-persistent implementation plus timed refresh.
//  Until then, `WebNotificationAggregator` may still run with stubbed
//  adapter data so the UI is exercised end to end.
//

import AppKit
import Combine
import Foundation
import WebKit

@MainActor
final class WebNotificationSessionManager: NSObject, ObservableObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = WebNotificationSessionManager()

    // MARK: State

    @Published private(set) var lastRefreshAt: Date?

    // MARK: Dependencies

    private let websiteDataStore: WKWebsiteDataStore = .default()
    private let processPool = WKProcessPool()
    private var webViews: [WebNotificationAppID: WKWebView] = [:]
    private var browserWebViews: [WebNotificationAppID: WKWebView] = [:]
    private var recentNotificationKeys: [String: Date] = [:]

    // MARK: Init

    private override init() {
        super.init()
    }

    // MARK: Public API

    /// Returns the WKWebView for the given adapter, creating it on first
    /// demand. This background instance is reserved for unread polling
    /// and preview scraping.
    func webView(for adapter: WebNotificationAppAdapter) -> WKWebView {
        if let existing = webViews[adapter.id] { return existing }

        let view = makeWebView(interactive: false)
        webViews[adapter.id] = view
        return view
    }

    /// Returns a separate, interactive WKWebView intended for the
    /// dedicated browser window. It shares cookies and process state
    /// with the background poller, but does not get reparented into the
    /// scraper flow.
    func browserWebView(for adapter: WebNotificationAppAdapter) -> WKWebView {
        if let existing = browserWebViews[adapter.id] { return existing }

        let view = makeWebView(interactive: true)
        browserWebViews[adapter.id] = view
        return view
    }

    func existingBrowserWebView(for adapter: WebNotificationAppAdapter) -> WKWebView? {
        browserWebViews[adapter.id]
    }

    var liveAppIDs: Set<WebNotificationAppID> {
        Set(browserWebViews.compactMap { appID, webView in
            webView.url == nil ? nil : appID
        })
    }

    /// Load the adapter's home URL into its WKWebView, creating the
    /// view if necessary. Safe to call redundantly.
    @discardableResult
    func loadHome(for adapter: WebNotificationAppAdapter) -> WKWebView {
        let view = webView(for: adapter)
        view.load(URLRequest(url: adapter.webURL))
        return view
    }

    /// Load the adapter's home URL into its dedicated browser WKWebView.
    @discardableResult
    func loadHomeInBrowser(for adapter: WebNotificationAppAdapter) -> WKWebView {
        let view = browserWebView(for: adapter)
        view.load(URLRequest(url: adapter.webURL))
        return view
    }

    /// Drop cookies and local storage for one adapter. Exposed to the
    /// Settings UI via a "Sign out" button.
    func signOut(from adapter: WebNotificationAppAdapter) async {
        let host = adapter.webURL.host ?? ""
        guard !host.isEmpty else { return }
        let records = await websiteDataStore.dataRecords(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
        )
        let filtered = records.filter { record in
            record.displayName.contains(host) ||
            host.contains(record.displayName)
        }
        guard !filtered.isEmpty else { return }
        await websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            for: filtered
        )
        WebNotificationState.shared.apply(unreadCount: 0, login: .signedOut, for: adapter.id)
        webViews.removeValue(forKey: adapter.id)?.stopLoading()
        browserWebViews.removeValue(forKey: adapter.id)?.stopLoading()
    }

    /// Reset every cached WKWebView without touching persistent cookies.
    func tearDownAllViews() {
        for view in webViews.values { view.stopLoading() }
        for view in browserWebViews.values { view.stopLoading() }
        webViews.removeAll()
        browserWebViews.removeAll()
    }

    /// Drop non-interactive background pollers while preserving the
    /// user-facing browser sessions and their cookies.
    func tearDownBackgroundViews() {
        for view in webViews.values { view.stopLoading() }
        webViews.removeAll()
    }

    // MARK: Web View Factory

    private func makeWebView(interactive: Bool) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = websiteDataStore
        config.processPool = processPool
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.addUserScript(Self.notificationBridgeScript)
        config.userContentController.add(self, name: Self.notificationHandlerName)

        let view = WKWebView(frame: .zero, configuration: config)
        view.uiDelegate = self
        view.navigationDelegate = interactive ? self : nil
        view.allowsBackForwardNavigationGestures = interactive
        view.allowsMagnification = interactive
        view.customUserAgent = Self.desktopChromeUserAgent
        view.setValue(interactive, forKey: "drawsBackground")
        return view
    }

    // MARK: WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            Task { @MainActor in
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if !["http", "https", "about", "blob", "data"].contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame == nil {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let appID = appID(for: webView) else { return }
        lastRefreshAt = Date()
        WebNotificationAggregator.shared.refreshApp(appID)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            self.handleNotificationBridgeMessage(message)
        }
    }

    private func handleNotificationBridgeMessage(_ message: WKScriptMessage) {
        guard message.name == Self.notificationHandlerName else { return }
        guard let appID = message.webView.flatMap(appID(for:)) else { return }

        let dict = message.body as? [String: Any]
        let kind = (dict?["kind"] as? String) ?? "notification"

        if kind == "badge" || kind == "title" {
            handleBadgeBridgeMessage(dict, appID: appID, kind: kind)
            return
        }

        let title = (dict?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (dict?["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = (dict?["tag"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = title?.isEmpty == false ? title! : appID.displayName
        let normalizedBody = body?.isEmpty == false ? body : "New notification"
        let key = "\(appID.rawValue)|\(normalizedTitle)|\(normalizedBody ?? "")|\(tag ?? "")"

        let now = Date()
        recentNotificationKeys = recentNotificationKeys.filter { now.timeIntervalSince($0.value) < 30 }
        if let last = recentNotificationKeys[key], now.timeIntervalSince(last) < 8 {
            return
        }
        recentNotificationKeys[key] = now

        let currentUnread = WebNotificationState.shared.snapshots[appID]?.unreadCount ?? 0
        WebNotificationState.shared.apply(
            unreadCount: max(1, currentUnread + 1),
            login: .signedIn,
            for: appID
        )

        NotchlyViewCoordinator.shared.showWebNotificationPreview(
            appID: appID,
            title: normalizedTitle,
            subtitle: normalizedBody,
            badgeCount: max(1, currentUnread + 1)
        )
        WebNotificationAggregator.shared.refreshApp(appID)
    }

    private func handleBadgeBridgeMessage(
        _ dict: [String: Any]?,
        appID: WebNotificationAppID,
        kind: String
    ) {
        let count: Int? = {
            if let intValue = dict?["count"] as? Int { return intValue }
            if let doubleValue = dict?["count"] as? Double { return Int(doubleValue) }
            if let stringValue = dict?["count"] as? String, let parsed = Int(stringValue) { return parsed }
            if let title = dict?["title"] as? String { return Self.parseUnreadCount(fromTitle: title) }
            return nil
        }()

        guard let count else { return }

        let normalizedCount = max(0, count)
        let currentUnread = WebNotificationState.shared.snapshots[appID]?.unreadCount ?? 0
        WebNotificationState.shared.apply(
            unreadCount: normalizedCount,
            login: .signedIn,
            for: appID
        )

        guard normalizedCount > currentUnread else { return }

        let title = (dict?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title?.isEmpty == false ? title! : appID.displayName
        let delta = max(1, normalizedCount - currentUnread)
        let subtitle = delta == 1 ? "New notification" : "\(delta) new notifications"

        NotchlyViewCoordinator.shared.showWebNotificationPreview(
            appID: appID,
            title: displayTitle,
            subtitle: subtitle,
            badgeCount: normalizedCount
        )
    }

    private func appID(for webView: WKWebView) -> WebNotificationAppID? {
        if let match = browserWebViews.first(where: { $0.value === webView }) {
            return match.key
        }
        if let match = webViews.first(where: { $0.value === webView }) {
            return match.key
        }
        return nil
    }

    // MARK: User Agent

    private static let desktopChromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    private static let notificationHandlerName = "notchlyNotification"
    private static let notificationBridgeScript = WKUserScript(
        source: """
        (function() {
          if (window.__notchlyNotificationBridgeInstalled) return;
          window.__notchlyNotificationBridgeInstalled = true;
          var OriginalNotification = window.Notification;

          function postNotchlyMessage(payload) {
            try {
              window.webkit.messageHandlers.notchlyNotification.postMessage(payload);
            } catch (e) {}
          }

          function postNotchlyNotification(title, options) {
            postNotchlyMessage({
              kind: 'notification',
              title: String(title || ''),
              body: String((options && options.body) || ''),
              icon: String((options && options.icon) || ''),
              tag: String((options && options.tag) || ''),
              href: String(window.location.href || '')
            });
          }

          if (OriginalNotification) {
            function NotchlyNotification(title, options) {
              postNotchlyNotification(title, options || {});
              return new OriginalNotification(title, options);
            }

            NotchlyNotification.prototype = OriginalNotification.prototype;
            try {
              Object.defineProperty(NotchlyNotification, 'permission', {
                get: function() { return OriginalNotification.permission; }
              });
            } catch (e) {}
            NotchlyNotification.requestPermission = function(callback) {
              return OriginalNotification.requestPermission(callback);
            };

            window.Notification = NotchlyNotification;
          }

          try {
            var registrationProto = window.ServiceWorkerRegistration && window.ServiceWorkerRegistration.prototype;
            var originalShowNotification = registrationProto && registrationProto.showNotification;
            if (registrationProto && originalShowNotification && !registrationProto.__notchlyShowNotificationPatched) {
              registrationProto.__notchlyShowNotificationPatched = true;
              registrationProto.showNotification = function(title, options) {
                postNotchlyNotification(title, options || {});
                return originalShowNotification.apply(this, arguments);
              };
            }
          } catch (e) {}

          try {
            var originalSetAppBadge = navigator.setAppBadge && navigator.setAppBadge.bind(navigator);
            if (originalSetAppBadge && !navigator.__notchlySetAppBadgePatched) {
              navigator.__notchlySetAppBadgePatched = true;
              navigator.setAppBadge = function(count) {
                postNotchlyMessage({
                  kind: 'badge',
                  count: Number(count || 0),
                  title: String(document.title || ''),
                  href: String(window.location.href || '')
                });
                return originalSetAppBadge.apply(navigator, arguments);
              };
            }

            var originalClearAppBadge = navigator.clearAppBadge && navigator.clearAppBadge.bind(navigator);
            if (originalClearAppBadge && !navigator.__notchlyClearAppBadgePatched) {
              navigator.__notchlyClearAppBadgePatched = true;
              navigator.clearAppBadge = function() {
                postNotchlyMessage({
                  kind: 'badge',
                  count: 0,
                  title: String(document.title || ''),
                  href: String(window.location.href || '')
                });
                return originalClearAppBadge.apply(navigator, arguments);
              };
            }
          } catch (e) {}

          try {
            var lastTitle = '';
            var titleTimer = null;
            function flushTitle() {
              titleTimer = null;
              var title = String(document.title || '');
              if (!title || title === lastTitle) return;
              lastTitle = title;
              postNotchlyMessage({
                kind: 'title',
                title: title,
                href: String(window.location.href || '')
              });
            }

            function scheduleTitleFlush() {
              if (titleTimer) return;
              titleTimer = setTimeout(flushTitle, 600);
            }

            var titleObserver = null;
            function installTitleObserver() {
              var titleNode = document.querySelector('title');
              if (!titleNode || titleObserver) return;
              titleObserver = new MutationObserver(scheduleTitleFlush);
              titleObserver.observe(titleNode, {
                childList: true,
                characterData: true,
                subtree: true
              });
            }

            installTitleObserver();
            document.addEventListener('DOMContentLoaded', installTitleObserver, { once: true });
            setTimeout(installTitleObserver, 1500);
            setTimeout(function() {
              installTitleObserver();
              flushTitle();
            }, 3000);
            setTimeout(flushTitle, 1500);
          } catch (e) {}
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )

    private static func parseUnreadCount(fromTitle title: String) -> Int? {
        let patterns = [
            #"\(\s*(\d{1,4})\s*\)"#,
            #"\[\s*(\d{1,4})\s*\]"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            guard let match = regex.firstMatch(in: title, range: range),
                  let countRange = Range(match.range(at: 1), in: title),
                  let count = Int(title[countRange]) else {
                continue
            }
            return max(0, count)
        }

        return nil
    }
}
