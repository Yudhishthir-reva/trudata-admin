//
//  SplashScreen.swift
//  Truedata
//

import SwiftUI

struct SplashScreen: View {

    @State private var logoScale: CGFloat = 0
    @State private var logoRotation: Double = 0

    var body: some View {
        ZStack {
            AppTheme.splashBackground.ignoresSafeArea()
            TruDataaLogo(size: 188)
                .scaleEffect(logoScale)
                .rotationEffect(.degrees(logoRotation))
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: runEntrance)
    }

    private func runEntrance() {
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 10)) {
            logoScale = 0.85
        }
        withAnimation(.easeInOut(duration: 0.8)) {
            logoRotation = 360
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            if UserDefaultManager.shared.isUserLoggedIn {
                AppRootManager.shared.setRootView(view: HomeScreen())
            } else {
                AppRootManager.shared.setRootView(view: AuthScreen())
            }
        }
    }
}

#Preview {
    SplashScreen()
}
