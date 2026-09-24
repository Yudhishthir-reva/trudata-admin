//
//  TruedataApp.swift
//  Truedata
//

import SwiftUI

@main
struct TruedataApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var rootManager = AppRootManager.shared

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .dynamicTypeSize(.large)
                .handleNoInternet()
                .preferredColorScheme(.light)
                .preventScreenshots()
        }
    }
}

struct RootContainerView: View {

    @ObservedObject private var rootManager = AppRootManager.shared

    var body: some View {
        ZStack {
            switch rootManager.currentRoot {
            case .splash:
                SplashScreen()
                    .transition(.opacity)
            case .auth:
                AuthScreen()
                    .transition(.opacity)
            case .home:
                HomeScreen()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: rootManager.currentRoot)
        .locationConsentPopoverHost()
        .onAppear {
            configureAppWindows()
        }
    }

    private func configureAppWindows() {
        for window in UIApplication.shared.connectedWindows {
            window.overrideUserInterfaceStyle = .light
            window.enableTapToDismissKeyboard()
            window.enableScreenCaptureProtection()
        }
    }
}
