//
//  EmbeddedWebView.swift
//  Notchly
//
//  NSViewRepresentable wrapper around the dedicated interactive
//  `WKWebView` owned by `WebNotificationSessionManager`. This view is
//  only used inside the separate browser window, not by the background
//  aggregator, so keyboard focus and text entry remain reliable.
//

import AppKit
import SwiftUI
import WebKit

struct EmbeddedWebView: NSViewRepresentable {
    let adapter: WebNotificationAppAdapter

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        attachWebView(to: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        attachWebView(to: nsView)
        guard let webView = nsView.subviews.first(where: { $0 is WKWebView }) as? WKWebView else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(webView)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        // Detach the shared web view so the next embed can re-parent it.
        for sub in nsView.subviews {
            if sub is WKWebView { sub.removeFromSuperview() }
        }
    }

    private func attachWebView(to container: NSView) {
        let webView = WebNotificationSessionManager.shared.browserWebView(for: adapter)
        if webView.url == nil {
            WebNotificationSessionManager.shared.loadHomeInBrowser(for: adapter)
        }

        if container.subviews.first !== webView {
            container.subviews.forEach { subview in
                if subview !== webView {
                    subview.removeFromSuperview()
                }
            }
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                webView.topAnchor.constraint(equalTo: container.topAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
    }
}
