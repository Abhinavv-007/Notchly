//
//  WebNotificationPeekView.swift
//  Notchly
//
//  Compact Dynamic Island-style notification preview shown while the
//  notch stays closed. Triggered by the web notification aggregator
//  when an app's unread count increases.
//

import SwiftUI

struct WebNotificationPeekView: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject private var coordinator = NotchlyViewCoordinator.shared
    private let peekAnimation = Animation.interactiveSpring(response: 0.44, dampingFraction: 0.86, blendDuration: 0)

    var body: some View {
        HStack(spacing: 0) {
            leftColumn

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 8)

            rightColumn
        }
        .frame(height: max(40, vm.effectiveClosedNotchHeight + 8))
        .transition(
            .asymmetric(
                insertion: .move(edge: .top)
                    .combined(with: .scale(scale: 0.96, anchor: .top))
                    .combined(with: .opacity),
                removal: .move(edge: .top)
                    .combined(with: .scale(scale: 0.98, anchor: .top))
                    .combined(with: .opacity)
            )
        )
        .animation(peekAnimation, value: coordinator.expandingView.webNotificationAppID)
        .animation(peekAnimation, value: coordinator.expandingView.title)
        .animation(peekAnimation, value: coordinator.expandingView.subtitle)
        .animation(peekAnimation, value: coordinator.expandingView.badgeCount)
    }

    private var leftColumn: some View {
        HStack(spacing: 8) {
            WebNotificationBrandIcon(app: appID, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(appID.displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.opacity)

                Text(titleText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 168, alignment: .leading)
    }

    private var rightColumn: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            Text(subtitleText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .contentTransition(.opacity)

            if coordinator.expandingView.badgeCount > 0 {
                Text(coordinator.expandingView.badgeCount > 99 ? "99+" : "\(coordinator.expandingView.badgeCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.9))
                    )
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 188, alignment: .trailing)
    }

    private var appID: WebNotificationAppID {
        coordinator.expandingView.webNotificationAppID ?? .gmail
    }

    private var titleText: String {
        let title = coordinator.expandingView.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "New notification" : title
    }

    private var subtitleText: String {
        let subtitle = coordinator.expandingView.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if subtitle.isEmpty {
            let count = coordinator.expandingView.badgeCount
            if count <= 1 { return "New activity" }
            return "\(count) new notifications"
        }
        return subtitle
    }
}

struct TempMailPeekView: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject private var coordinator = NotchlyViewCoordinator.shared
    private let peekAnimation = Animation.interactiveSpring(response: 0.44, dampingFraction: 0.86, blendDuration: 0)

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
                        )
                        .frame(width: 24, height: 24)

                    Image(systemName: "envelope")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Modih Mail")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .contentTransition(.opacity)

                    Text(titleText)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 168, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 8)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Text(subtitleText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(.opacity)

                if coordinator.expandingView.badgeCount > 0 {
                    Text(coordinator.expandingView.badgeCount > 99 ? "99+" : "\(coordinator.expandingView.badgeCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.9))
                        )
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 188, alignment: .trailing)
        }
        .frame(height: max(40, vm.effectiveClosedNotchHeight + 8))
        .transition(
            .asymmetric(
                insertion: .move(edge: .top)
                    .combined(with: .scale(scale: 0.96, anchor: .top))
                    .combined(with: .opacity),
                removal: .move(edge: .top)
                    .combined(with: .scale(scale: 0.98, anchor: .top))
                    .combined(with: .opacity)
            )
        )
        .animation(peekAnimation, value: coordinator.expandingView.title)
        .animation(peekAnimation, value: coordinator.expandingView.subtitle)
        .animation(peekAnimation, value: coordinator.expandingView.badgeCount)
    }

    private var titleText: String {
        let title = coordinator.expandingView.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "New Modih Mail message" : title
    }

    private var subtitleText: String {
        let subtitle = coordinator.expandingView.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if subtitle.isEmpty {
            let count = coordinator.expandingView.badgeCount
            if count <= 1 { return "New message" }
            return "\(count) unread messages"
        }
        return subtitle
    }
}
