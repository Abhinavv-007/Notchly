//
//  NotchlyHeader.swift
//  Notchly
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct NotchlyHeader: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared
    @ObservedObject var addonState = NotchAddonState.shared
    @ObservedObject var webNotifications = WebNotificationState.shared
    @StateObject var tvm = NotchlyStateViewModel.shared
    @Namespace private var headerSelection

    var body: some View {
        HStack(spacing: 0) {
            leftHeaderArea
                .frame(maxWidth: .infinity, alignment: .trailing)
                .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            rightHeaderArea
                .frame(maxWidth: .infinity, alignment: .leading)
                .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    private var leftHeaderArea: some View {
        HStack(spacing: 10) {
            if vm.notchState == .open {
                leftNavigationCluster
            }
        }
        .font(.system(.headline, design: .rounded))
    }

    private var rightHeaderArea: some View {
        HStack(spacing: 12) {
            if vm.notchState == .open {
                if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                    OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    rightNavigationCluster

                    if showUtilityButtons {
                        Spacer(minLength: 10)
                        utilityCluster
                    }
                }
            }
        }
        .font(.system(.headline, design: .rounded))
    }

    private var leftNavigationCluster: some View {
        HStack(spacing: 8) {
            headerCircleButton(
                id: "home",
                selected: activeDestination == .home
            ) {
                AddonCircleIndicator(
                    symbol: "house.fill",
                    accent: .white,
                    tooltip: "Home",
                    badge: .none
                ) {
                    select(.home)
                }
            }

            if Defaults[.addOnsEnabled] && Defaults[.modihMailEnabled] {
                headerCircleButton(
                    id: "mail",
                    selected: activeDestination == .mail
                ) {
                    AddonCircleIndicator(
                        symbol: "envelope",
                        accent: .white,
                        tooltip: "Modih Mail",
                        badge: mailBadge
                    ) {
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)) {
                            addonState.openModihMail()
                        }
                    }
                }
            }
        }
    }

    private var rightNavigationCluster: some View {
        HStack(spacing: 8) {
            if Defaults[.addOnsEnabled] && Defaults[.webNotificationsEnabled] {
                headerCircleButton(
                    id: "notifications",
                    selected: activeDestination == .notifications
                ) {
                    AddonCircleIndicator(
                        symbol: "bell",
                        accent: .white,
                        tooltip: "Web Notifications",
                        badge: notificationBadge
                    ) {
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)) {
                            addonState.openWebNotifications()
                            WebNotificationAggregator.shared.refreshNow()
                        }
                    }
                }
            }

            if Defaults[.notchlyEnabled] {
                headerCircleButton(
                    id: "notchly",
                    selected: activeDestination == .notchly
                ) {
                    AddonCircleIndicator(
                        symbol: "tray.fill",
                        accent: .white,
                        tooltip: "Notchly",
                        badge: .none
                    ) {
                        select(.notchly)
                    }
                }
            }
        }
    }

    private var utilityCluster: some View {
        HStack(spacing: 4) {
            if Defaults[.showMirror] {
                Button(action: {
                    vm.toggleCameraPreview()
                }) {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "web.camera")
                                .foregroundColor(.white)
                                .padding()
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }

            if Defaults[.settingsIconInNotch] {
                Button(action: {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.showWindow()
                    }
                }) {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                                .padding()
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var showUtilityButtons: Bool {
        Defaults[.showMirror] || Defaults[.settingsIconInNotch]
    }

    private var mailBadge: AddonCircleIndicator.Badge {
        let count = addonState.modihMail.state.unreadCount
        if count == 0 { return .none }
        if count == 1 { return .dot }
        return .count(count)
    }

    private var notificationBadge: AddonCircleIndicator.Badge {
        let total = webNotifications.totalUnreadCount
        if total == 0 { return .none }
        if total == 1 { return .dot }
        return .count(total)
    }

    private func select(_ view: NotchViews) {
        addonState.dismiss(returnToHome: false)
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)) {
            coordinator.currentView = view
        }
    }

    private func headerCircleButton<Content: View>(
        id: String,
        selected: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            if selected {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                    )
                    .matchedGeometryEffect(id: "header-selection", in: headerSelection)
                    .frame(
                        width: AddonChromeMetrics.indicatorDiameter + 6,
                        height: AddonChromeMetrics.indicatorDiameter + 6
                    )
            }

            content()
                .frame(
                    width: AddonChromeMetrics.indicatorDiameter,
                    height: AddonChromeMetrics.indicatorDiameter
                )
        }
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0), value: activeDestination)
    }

    private var activeDestination: HeaderDestination {
        switch coordinator.currentView {
        case .home:
            return .home
        case .notchly:
            return .notchly
        case .addOns:
            return addonState.isShowingWebNotifications ? .notifications : .mail
        }
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    NotchlyHeader().environmentObject(NotchlyViewModel())
}

private enum HeaderDestination {
    case home
    case notchly
    case mail
    case notifications
}
