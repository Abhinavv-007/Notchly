//
//  AddonIconButton.swift
//  Notchly
//
//  Small icon button with hover + press states used across the
//  Notchly Add-On inline panels.
//

import SwiftUI

struct AddonIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: { fire() }) {
            Image(systemName: systemName)
                .font(.system(size: 10.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(isHovering ? 1.0 : 0.82))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.12 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(isHovering ? 0.18 : 0.0), lineWidth: 0.6)
                        )
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isHovering = hovering
            }
        }
    }

    private func fire() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                isPressed = false
            }
            action()
        }
    }
}
