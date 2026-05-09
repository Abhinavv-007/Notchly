//
//  WelcomeView.swift
//  Notchly
//
//  Created by Richard Kunkli on 2024. 09. 26..
//

import SwiftUI
import SwiftUIIntrospect

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil
    @State private var isPresented = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.effectiveAccent.opacity(0.12),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                NotchlyIntroLogo(isPresented: isPresented, glowPulse: glowPulse)
                    .padding(.bottom, 2)

                VStack(spacing: 8) {
                    Text("Notchly")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("A compact notch hub for mail, web alerts, media, and quick drops.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 42)
                }
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : 10)

                HStack(spacing: 10) {
                    NotchlyIntroPill(icon: "envelope", title: "Mail")
                    NotchlyIntroPill(icon: "bell.badge", title: "Alerts")
                    NotchlyIntroPill(icon: "tray.and.arrow.down", title: "Drops")
                }
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : 12)

                Spacer()

                Button {
                    onGetStarted?()
                } label: {
                    HStack(spacing: 8) {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : 14)

                Text("by Abhinav Raj")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(0.75)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                isPresented = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

private struct NotchlyIntroLogo: View {
    let isPresented: Bool
    let glowPulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.effectiveAccent.opacity(glowPulse ? 0.22 : 0.10))
                .frame(width: 178, height: 178)
                .blur(radius: 20)
                .scaleEffect(glowPulse ? 1.08 : 0.92)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 150, height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 24, y: 18)

            Image("logo2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack {
                Capsule()
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 58, height: 16)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .offset(y: -3)

                Spacer()
            }
            .frame(width: 150, height: 150)
        }
        .scaleEffect(isPresented ? 1 : 0.88)
        .opacity(isPresented ? 1 : 0)
    }
}

private struct NotchlyIntroPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

#Preview {
    WelcomeView()
}
