//
//  WhatsNewView.swift
//  Notchly
//
//  Polished "what's new" sheet shown after first launch following an update.
//

import SwiftUI

struct WhatsNewView: View {
    @Binding var isPresented: Bool

    private struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: String
        let detail: String
    }

    private let highlights: [Highlight] = [
        Highlight(
            icon: "envelope.fill",
            tint: .blue,
            title: "Modih Mail",
            detail: "Disposable inbox, one click left of the notch."
        ),
        Highlight(
            icon: "bell.fill",
            tint: .orange,
            title: "Web notifications",
            detail: "Discord, Telegram, Gmail, Slack and more — sign in once."
        ),
        Highlight(
            icon: "rectangle.expand.vertical",
            tint: .purple,
            title: "Sliding pills",
            detail: "Side indicators slide outward when music plays."
        ),
        Highlight(
            icon: "tray.full.fill",
            tint: .green,
            title: "File shelf",
            detail: "Drag, Quick Look, share, drag back out."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.30), Color.purple.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Image("logo2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                    Text("What's new in Notchly")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(versionLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(highlights) { item in
                    highlightRow(item)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            HStack {
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/Abhinavv-007/Notchly") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.regular)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Text("Get started")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 460)
        .background(Color(.windowBackgroundColor))
    }

    private func highlightRow(_ item: Highlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(item.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.releaseVersionNumber ?? "—"
        return "Version \(version) · Abhinav Raj"
    }
}

#Preview {
    WhatsNewView(isPresented: .constant(true))
}
