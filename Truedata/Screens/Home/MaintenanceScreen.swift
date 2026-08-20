//
//  MaintenanceScreen.swift
//  Truedata
//

import SwiftUI

struct MaintenanceScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.darkMidnightBlue.opacity(0.12),
                    Color.white,
                    AppTheme.darkMidnightBlue.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.darkMidnightBlue.opacity(0.85))
                    .padding(.bottom, 8)

                Text("We're Currently Under Maintenance")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.darkMidnightBlue)
                    .multilineTextAlignment(.center)

                Text("Our team is working hard to improve your experience.\nWe'll be back shortly!")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Thank you for your patience")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.darkMidnightBlue.opacity(0.7))
            }
            .padding(32)
        }
    }
}

#Preview {
    MaintenanceScreen()
}
