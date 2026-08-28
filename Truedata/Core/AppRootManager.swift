//
//  AppRootManager.swift
//  Truedata
//

import Foundation
import Combine
import SwiftUI
import UIKit

enum AppRootScreen: Equatable {
    case splash
    case auth
    case home
}

@MainActor
final class AppRootManager: ObservableObject {

    static let shared = AppRootManager()

    @Published var currentRoot: AppRootScreen = .splash
    var isSheetPresented = false

    private init() {}

    func switchToHome(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.currentRoot = .home
            }
        } else {
            self.currentRoot = .home
        }
    }

    func switchToAuth(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.currentRoot = .auth
            }
        } else {
            self.currentRoot = .auth
        }
    }

    func switchToSplash(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.currentRoot = .splash
            }
        } else {
            self.currentRoot = .splash
        }
    }

    /// Sets the root view with backward compatibility and declarative state synchronization
    func setRootView<T: View>(view: T, window: UIWindow? = nil) {
        if view is HomeScreen {
            switchToHome()
            return
        }
        if view is AuthScreen {
            switchToAuth()
            return
        }
        if view is SplashScreen {
            switchToSplash()
            return
        }

        let targetWindow = window ?? UIApplication.shared.connectedKeyWindow
        guard let targetWindow else { return }

        targetWindow.overrideUserInterfaceStyle = .light
        targetWindow.enableTapToDismissKeyboard()
        let hostingController = UIHostingController(rootView: view.handleNoInternet().preferredColorScheme(.light))
        hostingController.overrideUserInterfaceStyle = .light
        targetWindow.rootViewController = hostingController
        UIView.transition(
            with: targetWindow,
            duration: 0.35,
            options: .transitionCrossDissolve,
            animations: nil,
            completion: nil
        )
    }
}

extension UIApplication {
    var connectedWindows: [UIWindow] {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    }

    var connectedKeyWindow: UIWindow? {
        connectedWindows.first { $0.isKeyWindow } ?? connectedWindows.first
    }
}
