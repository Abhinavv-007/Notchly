//
//  NotchOutsideClickMonitor.swift
//  Notchly
//
//  Global mouse-down watcher that closes the notch when the user clicks
//  outside the notch window while an add-on panel is active.
//
//  Add-ons intentionally disable the normal hover-away auto-close so the
//  TEMP Mail and Web Notifications panels stay open for as long as the
//  user needs them. This monitor restores the "tap anywhere else to
//  dismiss" affordance without interfering with the existing hover-away
//  close behavior used by Home / Notchly views.
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Lightweight NSView bridge used to reach the underlying `NSWindow`
/// from SwiftUI. Attach via `.background(WindowReader { ... })`.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    final class Reader: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }

    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: Reader, context: Context) {}
}

@MainActor
final class NotchOutsideClickMonitor {
    static let shared = NotchOutsideClickMonitor()

    private var monitor: Any?
    private var onDismiss: (() -> Void)?
    private weak var window: NSWindow?

    private init() {}

    /// Start watching global mouse-down events. `window` is the notch
    /// window whose frame is treated as the "inside" region; any click
    /// outside that frame triggers `onDismiss`. Safe to call
    /// redundantly — repeated calls replace the previous monitor.
    func start(window: NSWindow?, onDismiss: @escaping () -> Void) {
        stop()
        self.window = window
        self.onDismiss = onDismiss

        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handle(event: event)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onDismiss = nil
        window = nil
    }

    // MARK: - Helpers

    private func handle(event: NSEvent) {
        let location = NSEvent.mouseLocation
        if let window, window.frame.insetBy(dx: -8, dy: -8).contains(location) {
            // Click landed inside the notch chrome; let the view handle it.
            return
        }
        onDismiss?()
    }
}
