//
//  NotchAddonState.swift
//  Notchly
//
//  Central observable state for the Notchly Add-On layer.
//
//  Responsibilities:
//  - Track which inline side panel is currently focused (if any).
//  - Own the MODIH Mail view model lifecycle.
//  - Expose the aggregated Web Notification state.
//  - Route `NotchlyViewCoordinator.currentView` to `.addOns` when the
//    user activates a panel, and back to `.home` when dismissed.
//
//  This class intentionally does not mutate `NotchlyViewModel.notchState`
//  itself. The caller (typically `NotchSideIndicatorsView`) opens the
//  notch via `vm.open()` and then asks this object to focus a panel.
//

import Combine
import Defaults
import SwiftUI

@MainActor
final class NotchAddonState: ObservableObject {
    static let shared = NotchAddonState()

    // MARK: Published Routing State

    /// Which inline panel should be visually focused. `.none` keeps the
    /// pre-add-on notch appearance unchanged.
    @Published private(set) var activePanel: NotchAddonPanel = .none

    /// True while the user is hovering or expanding a side indicator but
    /// the notch has not yet fully opened. Reserved for future peek
    /// animations; currently unused.
    @Published var isPeeking: Bool = false

    // MARK: Owned Feature State

    let modihMail: ModihMailViewModel
    let webNotifications: WebNotificationState

    // MARK: Lifecycle

    private init() {
        self.modihMail = ModihMailViewModel()
        self.webNotifications = WebNotificationState.shared
    }

    // MARK: Panel Routing

    /// Invoked by the left circular indicator. Focuses MODIH Mail and
    /// triggers a lightweight refresh if enabled.
    func openModihMail() {
        guard Defaults[.addOnsEnabled], Defaults[.modihMailEnabled] else { return }
        activePanel = .modihMail
        NotchlyViewCoordinator.shared.currentView = .addOns
        modihMail.requestLoadIfNeeded()
        modihMail.startLiveRefresh()
    }

    /// Invoked by the right circular indicator. Focuses the web
    /// notifications strip.
    func openWebNotifications() {
        guard Defaults[.addOnsEnabled], Defaults[.webNotificationsEnabled] else { return }
        activePanel = .webNotifications
        NotchlyViewCoordinator.shared.currentView = .addOns
        modihMail.stopLiveRefresh()
        WebNotificationAggregator.shared.refreshNow()
    }

    /// Drills into a specific web app inside the right column while
    /// keeping the left (MODIH) column visible.
    func focusWebApp(_ id: WebNotificationAppID) {
        guard Defaults[.addOnsEnabled], Defaults[.webNotificationsEnabled] else { return }
        activePanel = .webApp(id)
        NotchlyViewCoordinator.shared.currentView = .addOns
        modihMail.stopLiveRefresh()
    }

    /// Collapse add-on focus back to the default notch content. Safe to
    /// call redundantly.
    func dismiss(returnToHome: Bool = true) {
        activePanel = .none
        modihMail.stopLiveRefresh()
        if returnToHome, NotchlyViewCoordinator.shared.currentView == .addOns {
            NotchlyViewCoordinator.shared.currentView = .home
        }
    }

    // MARK: Derived Flags

    /// True when the inline panel should occupy space inside `NotchHomeView`.
    var isInlinePanelVisible: Bool {
        guard Defaults[.addOnsEnabled] else { return false }
        return activePanel != .none
    }

    /// True when the left circular indicator should render in the
    /// collapsed notch chrome.
    var showsLeftIndicator: Bool {
        Defaults[.addOnsEnabled] && Defaults[.modihMailEnabled]
    }

    /// True when the right circular indicator should render in the
    /// collapsed notch chrome.
    var showsRightIndicator: Bool {
        Defaults[.addOnsEnabled] && Defaults[.webNotificationsEnabled]
    }

    var isShowingWebNotifications: Bool {
        switch activePanel {
        case .webNotifications, .webApp:
            return true
        case .none, .modihMail:
            return false
        }
    }
}
