//
//  ModihMailPanel.swift
//  Notchly
//
//  Premium TEMP Mail surface used inside the inline addon panel.
//  Shows the active disposable address, gives one-tap copy/refresh/replace,
//  renders skeleton loaders during fetch, and keeps a live preview of recent
//  messages with sender avatars + smooth state transitions.
//

import Defaults
import SwiftUI

struct ModihMailPanel: View {
    @ObservedObject var addonState: NotchAddonState = .shared
    @State private var copiedAt: Date?
    @State private var nowTick: Date = Date()
    @State private var lastRefreshedAt: Date?

    private let nowTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var vm: ModihMailViewModel { addonState.modihMail }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            addressRow
            contentArea
                .animation(.smooth(duration: 0.28), value: stateID)
            Spacer(minLength: 0)
        }
        .onReceive(nowTimer) { now in nowTick = now }
        .onChange(of: vm.lastCopiedAt) { _, newValue in
            copiedAt = newValue
        }
        .onChange(of: stateID) { _, _ in
            lastRefreshedAt = Date()
        }
    }

    // Stable id used to drive transitions between idle/loading/loaded/etc.
    private var stateID: String {
        switch vm.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded(_, let messages): return "loaded:\(messages.count)"
        case .empty: return "empty"
        case .error(let t): return "error:\(t.prefix(20))"
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("Modih Mail")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            connectionDot

            Spacer(minLength: 0)

            if let lastRefreshedAt {
                Text("· refreshed \(Self.relativeDate(lastRefreshedAt, ref: nowTick))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .transition(.opacity)
            }

            planBadge
        }
    }

    private var connectionDot: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(connectionColor.opacity(0.45), lineWidth: 1)
                    .scaleEffect(vm.isBusy ? 2.2 : 1)
                    .opacity(vm.isBusy ? 0 : 0)
                    .animation(
                        vm.isBusy
                            ? .easeOut(duration: 0.9).repeatForever(autoreverses: false)
                            : .default,
                        value: vm.isBusy
                    )
            )
            .help(connectionHelp)
    }

    private var connectionColor: Color {
        if vm.state.errorText != nil { return .orange }
        if visibleMailbox != nil { return .green }
        return .gray
    }

    private var connectionHelp: String {
        if let err = vm.state.errorText { return err }
        return visibleMailbox != nil ? "Connected" : "Not connected"
    }

    private var planBadge: some View {
        Text(visibleMailbox?.plan.displayName ?? "—")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.white.opacity(0.10)))
            .foregroundStyle(.white.opacity(0.78))
    }

    // MARK: - Address row

    private var addressRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(addressDisplay)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCopiedFlash {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Copied")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: showCopiedFlash)

            HStack(spacing: 6) {
                wideActionButton(systemName: "doc.on.doc", label: "Copy") {
                    vm.copyEmailToPasteboard()
                }
                .disabled(visibleMailbox == nil)

                wideActionButton(
                    systemName: vm.isBusy ? "circle.dotted" : "arrow.clockwise",
                    label: "Refresh"
                ) {
                    vm.refresh(showLoading: false)
                }
                .disabled(vm.isBusy)

                wideActionButton(systemName: "sparkles", label: "New") {
                    vm.regenerate()
                }
                .disabled(vm.isBusy)
            }
        }
    }

    private var addressDisplay: String {
        if let mailbox = visibleMailbox, !mailbox.emailAddress.isEmpty {
            return mailbox.emailAddress
        }
        if vm.state.isLoading { return "Generating address…" }
        return "—"
    }

    private var visibleMailbox: ModihMailbox? {
        vm.state.mailbox ?? MailboxPersistence.restore()
    }

    private var showCopiedFlash: Bool {
        guard let copiedAt else { return false }
        return Date().timeIntervalSince(copiedAt) < 1.6
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if let selectedMessage = vm.selectedMessage {
            messageDetail(selectedMessage)
        } else {
            switch vm.state {
            case .idle:
                idleState
            case .loading:
                skeletonRows
            case .loaded(_, let messages):
                messagesList(messages)
            case .empty:
                emptyState
            case .error(let text):
                errorState(text)
            }
        }
    }

    private var idleState: some View {
        HStack(spacing: 6) {
            Image(systemName: "envelope.open")
                .foregroundStyle(.white.opacity(0.5))
            Text("Loading your inbox…")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .onAppear { vm.requestLoadIfNeeded() }
    }

    // Skeleton placeholder rows shown during initial fetch.
    private var skeletonRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                skeletonRow
                    .opacity(0.85 - (Double(i) * 0.18))
            }
        }
    }

    private var skeletonRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 18, height: 18)
                .shimmer()

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                    .shimmer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 7)
                    .frame(maxWidth: 140)
                    .shimmer()
            }
        }
    }

    private func messagesList(_ messages: [ModihMessage]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(messages.prefix(3)) { message in
                messageRow(message)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func messageRow(_ message: ModihMessage) -> some View {
        Button {
            vm.openMessage(message)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                SenderAvatar(seed: message.senderDisplay, unread: message.unread)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(message.senderDisplay)
                            .font(.system(size: 10.5, weight: message.unread ? .semibold : .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Self.relativeDate(message.receivedAt, ref: nowTick))
                            .font(.system(size: 9, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text(message.subject ?? "(no subject)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    if let preview = message.bodyPreview, !preview.isEmpty, preview != message.subject {
                        Text(preview)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(message.unread ? Color.white.opacity(0.04) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static func relativeDate(_ date: Date, ref: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: ref)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.32), .cyan.opacity(0.18)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 22)
                    Image(systemName: "tray")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Inbox is empty")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Send mail to your address — it'll show up here.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func messageDetail(_ message: ModihMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    vm.closeMessage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if let code = message.oneTimeCodeCandidate {
                    Button {
                        vm.copyMessageCode(message)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedFlash ? "checkmark" : "number")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(showCopiedFlash ? "Copied" : code)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(showCopiedFlash ? Color.green.opacity(0.32) : Color.blue.opacity(0.22))
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopiedFlash)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                SenderAvatar(seed: message.senderDisplay, unread: false, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.senderDisplay)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(message.subject?.isEmpty == false ? message.subject! : "New message")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(Self.relativeDate(message.receivedAt, ref: nowTick))
                        .font(.system(size: 9.5, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(message.bodyPreview?.isEmpty == false ? message.bodyPreview! : "No preview text available yet.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 124)

            HStack(spacing: 6) {
                Button("Refresh") { vm.refresh(showLoading: false) }
                    .controlSize(.mini)

                Button("Open in browser") { vm.openInboxInBrowser() }
                    .controlSize(.mini)
            }
        }
        .padding(.top, 2)
    }

    private func errorState(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Button("Retry") { vm.refresh() }
                    .controlSize(.mini)

                Button("New mailbox") { vm.regenerate() }
                    .controlSize(.mini)
                    .disabled(vm.isBusy)

                Button("Open in browser") { vm.openInboxInBrowser() }
                    .controlSize(.mini)
            }
        }
    }

    private func wideActionButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sender avatar

private struct SenderAvatar: View {
    let seed: String
    let unread: Bool
    var size: CGFloat = 18

    private var initials: String {
        let cleaned = seed.replacingOccurrences(of: "<.*?>", with: "", options: .regularExpression)
        let parts = cleaned
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(2)
        let chars = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return chars.isEmpty ? "?" : chars.joined()
    }

    private var hue: Double {
        let h = abs(seed.unicodeScalars.reduce(0) { Int($0) &+ Int($1.value) })
        return Double(h % 360) / 360.0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.85),
                            Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(unread ? 0.45 : 0.18), lineWidth: unread ? 1 : 0.6)
                )
            Text(initials)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.6)
                    .offset(x: geo.size.width * phase)
                    .blendMode(.plusLighter)
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .clipped()
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
