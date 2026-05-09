//
//  NotchAddonInlinePanel.swift
//  Notchly
//
//  Inline single-panel container that appears when the user activates
//  an add-on. TEMP Mail and Web Notifications are routed as separate
//  screens so the notch never renders both modules at once.
//

import SwiftUI

struct NotchAddonInlinePanel: View {
    @ObservedObject var addonState: NotchAddonState = .shared

    var body: some View {
        Group {
            switch addonState.activePanel {
            case .modihMail:
                panelContainer {
                    ModihMailPanel()
                }
            case .webNotifications, .webApp:
                panelContainer {
                    WebNotificationsPanel()
                }
            case .none:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    private func panelContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxHeight: .infinity)
    }
}
