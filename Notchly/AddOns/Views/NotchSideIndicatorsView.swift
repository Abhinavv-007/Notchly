//
//  NotchSideIndicatorsView.swift
//  Notchly
//
//  Two small circular indicators that flank the collapsed notch pill:
//  envelope (TEMP Mail) on the left, bell (Web Notifications) on the
//  right. The HStack is intrinsically sized so it hugs the notch
//  instead of stretching toward the menu bar edges.
//
//  Installed via `.overlay(alignment: .top)` on the outer ContentView
//  ZStack. Because the HStack has no `Spacer(minLength: .infinity)`,
//  SwiftUI centers the overlay horizontally with respect to the
//  window, which matches the notch's own horizontal center.
//

import Defaults
import SwiftUI

struct NotchSideIndicatorsView: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject var addonState = NotchAddonState.shared
    @ObservedObject var webNotifications = WebNotificationState.shared
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared

    private let sideGap: CGFloat = AddonChromeMetrics.sideGap
    private let indicatorSize: CGFloat = AddonChromeMetrics.indicatorDiameter

    var body: some View {
        HStack(spacing: 0) {
            leftIndicator
                .frame(width: indicatorSize, height: indicatorSize)
                .opacity(addonState.showsLeftIndicator ? 1 : 0)
                .allowsHitTesting(addonState.showsLeftIndicator)

            // Fixed-width transparent band that matches the closed notch
            // pill. Keeps the indicators hugging the pill's outer edges.
            Color.clear
                .frame(width: indicatorBandWidth)

            rightIndicator
                .frame(width: indicatorSize, height: indicatorSize)
                .opacity(addonState.showsRightIndicator ? 1 : 0)
                .allowsHitTesting(addonState.showsRightIndicator)
        }
        .fixedSize()
        .frame(height: max(indicatorSize, vm.effectiveClosedNotchHeight))
        .background {
            if visible && !showsClosedMediaIsland {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
                    .frame(width: backdropWidth, height: backdropHeight)
                    .shadow(color: .black.opacity(0.24), radius: 6, x: 0, y: 2)
                    .allowsHitTesting(false)
            }
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .animation(.smooth(duration: 0.25), value: visible)
    }

    // MARK: - Visibility

    private var visible: Bool {
        guard Defaults[.addOnsEnabled] else { return false }
        guard vm.notchState == .closed else { return false }
        guard !(coordinator.expandingView.show && coordinator.expandingView.type == .webNotification) else { return false }
        return true
    }

    private var indicatorBandWidth: CGFloat {
        islandWidth + sideGap * 2
    }

    private var backdropWidth: CGFloat {
        indicatorBandWidth + indicatorSize * 2 + 10
    }

    private var backdropHeight: CGFloat {
        max(indicatorSize + 6, vm.closedNotchSize.height + 4)
    }

    private var islandWidth: CGFloat {
        var width = vm.closedNotchSize.width
        let sideExpansion = 2 * max(0, vm.closedNotchSize.height - 12) + 20

        let showsClosedFaceIsland =
            !coordinator.expandingView.show
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
            && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed

        if showsClosedMediaIsland || showsClosedFaceIsland {
            width += sideExpansion
        }

        return width
    }

    private var showsClosedMediaIsland: Bool {
        (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled
    }

    // MARK: - Indicators

    private var leftIndicator: some View {
        AddonCircleIndicator(
            symbol: "envelope",
            accent: .white,
            tooltip: "TEMP Mail",
            badge: mailBadge
        ) {
            openTempMail()
        }
    }

    private var mailBadge: AddonCircleIndicator.Badge {
        let count = addonState.modihMail.state.unreadCount
        if count == 0 { return .none }
        if count == 1 { return .dot }
        return .count(count)
    }

    private var rightIndicator: some View {
        let total = webNotifications.totalUnreadCount
        let badge: AddonCircleIndicator.Badge
        if total == 0 {
            badge = .none
        } else if total == 1 {
            badge = .dot
        } else {
            badge = .count(total)
        }
        return AddonCircleIndicator(
            symbol: "bell",
            accent: .white,
            tooltip: "Web Notifications",
            badge: badge
        ) {
            openWebNotifications()
        }
    }

    // MARK: - Actions

    private func openTempMail() {
        addonState.openModihMail()
        open()
    }

    private func openWebNotifications() {
        addonState.openWebNotifications()
        open()
    }

    private func open() {
        if vm.notchState == .closed {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)) {
                vm.open()
            }
        }
    }
}

// MARK: - Circle Indicator

struct AddonCircleIndicator: View {
    enum Badge: Equatable {
        case none
        case dot
        case count(Int)
    }

    let symbol: String
    let accent: Color
    let tooltip: String
    let badge: Badge
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: { performAction() }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovering ? 0.45 : 0.28),
                                        Color.white.opacity(isHovering ? 0.18 : 0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(isHovering ? 0.35 : 0.2), radius: isHovering ? 6 : 3, x: 0, y: 2)

                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent.opacity(isHovering ? 1 : 0.82))

                badgeOverlay
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : (isHovering ? 1.08 : 1.0))
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                isHovering = hovering
            }
        }
    }

    private func performAction() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            isPressed = true
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isPressed = false
            }
            action()
        }
    }

    @ViewBuilder
    private var badgeOverlay: some View {
        switch badge {
        case .none:
            EmptyView()
        case .dot:
            Circle()
                .fill(Color.red)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                )
                .frame(width: 7, height: 7)
                .offset(x: 7, y: -7)
        case .count(let value):
            let text = value > 99 ? "99+" : "\(value)"
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
                .offset(x: 9, y: -8)
        }
    }
}
