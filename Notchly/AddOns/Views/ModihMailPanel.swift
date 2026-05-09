//
//  ModihMailPanel.swift
//  Notchly
//
//  Left column of the inline add-on panel. TEMP Mail now behaves as a
//  real disposable inbox surface: current address, copy / refresh /
//  replace controls, and a live preview of recent messages.
//

import Defaults
import SwiftUI

struct ModihMailPanel: View {
    @ObservedObject var addonState: NotchAddonState = .shared

    private var vm: ModihMailViewModel { addonState.modihMail }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            addressRow
            contentArea
            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("TEMP Mail")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            connectionDot

            Spacer(minLength: 0)

            planBadge
        }
    }

    private var connectionDot: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 6, height: 6)
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
            .background(
                Capsule().fill(Color.white.opacity(0.08))
            )
            .foregroundStyle(.white.opacity(0.7))
    }

    // MARK: - Address row

    private var addressRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(addressDisplay)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                wideActionButton(systemName: "doc.on.doc", label: "Copy") {
                    vm.copyEmailToPasteboard()
                }
                .disabled(visibleMailbox == nil)

                wideActionButton(systemName: "arrow.clockwise", label: "Refresh") {
                    vm.refresh(showLoading: false)
                }
                .disabled(vm.isBusy)

                wideActionButton(systemName: "trash", label: "New Mail") {
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
        if vm.state.isLoading { return "Loading…" }
        return "—"
    }

    private var visibleMailbox: ModihMailbox? {
        vm.state.mailbox ?? MailboxPersistence.restore()
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
            loadingState
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
                .foregroundStyle(.gray)
            Text("Tap to load your inbox")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
        .onAppear { vm.requestLoadIfNeeded() }
    }

    private var loadingState: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("Loading TEMP Mail…")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
    }

    private func messagesList(_ messages: [ModihMessage]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(messages.prefix(3)) { message in
                messageRow(message)
            }
        }
    }

    private func messageRow(_ message: ModihMessage) -> some View {
        Button {
            vm.openMessage(message)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            message.unread
                                ? LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.10)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 6, height: 6)
                }
                .frame(width: 6)
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(message.senderDisplay)
                            .font(.system(size: 10.5, weight: message.unread ? .semibold : .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Self.relativeDate(message.receivedAt))
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static func relativeDate(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray")
                .foregroundStyle(.gray)
            Text("No mail yet")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
            Spacer(minLength: 0)
            Button("Refresh") { vm.refresh(showLoading: false) }
                .controlSize(.mini)
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
                            Image(systemName: "number")
                            Text(code)
                        }
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.22)))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.senderDisplay)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                Text(message.subject?.isEmpty == false ? message.subject! : "New message")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(Self.relativeDate(message.receivedAt))
                    .font(.system(size: 9.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(message.bodyPreview?.isEmpty == false ? message.bodyPreview! : "No preview text available yet.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 124)

            HStack(spacing: 6) {
                Button("Refresh") { vm.refresh(showLoading: false) }
                    .controlSize(.mini)

                Button("Open Web") { vm.openInboxInBrowser() }
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

                Button("New Mailbox") { vm.regenerate() }
                    .controlSize(.mini)
                    .disabled(vm.isBusy)

                Button("Open Web") { vm.openInboxInBrowser() }
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
