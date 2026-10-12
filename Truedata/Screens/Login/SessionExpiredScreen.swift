//
//  SessionExpiredScreen.swift
//  Truedata
//

import SwiftUI

/// Android `AccountBlockedScreen`. Shown once the server rejects the stored token, so the user
/// learns why they were signed out instead of landing on the login form with no explanation.
/// Counts down, then hands over to `AuthScreen`.
struct SessionExpiredScreen: View {

    /// Android waits 5 seconds before relaunching into login.
    private static let countdownSeconds: TimeInterval = 5

    @State private var progress: CGFloat = 1
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                countdownRing

                Text("You have been logged out.")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("You will be redirected to the login screen shortly.")
                    .font(.system(size: 16))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }
            .padding(16)
        }
        .onAppear(perform: startCountdown)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(
                    DashboardTheme.neutralLight.opacity(0.4),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DashboardTheme.primaryBlueDark,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 120, height: 120)
    }

    private func startCountdown() {
        // onAppear can fire again when the window re-attaches; the countdown must not restart.
        guard !hasStarted else { return }
        hasStarted = true

        withAnimation(.linear(duration: Self.countdownSeconds)) {
            progress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.countdownSeconds) {
            guard AppRootManager.shared.currentRoot == .sessionExpired else { return }
            AppRootManager.shared.switchToAuth()
        }
    }
}

#Preview {
    SessionExpiredScreen()
}
