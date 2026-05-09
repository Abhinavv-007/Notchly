//
//  OnboardingFinishView.swift
//  Notchly
//
//  Created by Alexander on 2025-06-23.
//


import SwiftUI

struct OnboardingFinishView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void
    @State private var isPresented = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color.effectiveAccent.opacity(0.09),
                    Color.black.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.effectiveAccent.opacity(pulse ? 0.18 : 0.08))
                        .frame(width: 148, height: 148)
                        .blur(radius: 18)

                    Image("logo2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                }
                .scaleEffect(isPresented ? 1 : 0.9)
                .opacity(isPresented ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Notchly is ready")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)

                    Text("The notch, mail, notifications, media, and quick sharing are set up. You can tune the details in Settings any time.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 42)
                }
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : 10)

                Spacer()
                Spacer()

                VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label("Customize in Settings", systemImage: "gear")
                        .controlSize(.large)
                }
                .controlSize(.large)

                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(24)
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                isPresented = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    OnboardingFinishView(onFinish: { }, onOpenSettings: { })
}
