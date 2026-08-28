//
//  AppDelegate.swift
//  Truedata
//

import UIKit
import UserNotifications
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        IQKeyboardToolbarManager.shared.isEnabled = true

        registerForPushNotifications()
        NetworkMonitor.shared.start()

        DispatchQueue.main.async {
            for window in UIApplication.shared.connectedWindows {
                window.overrideUserInterfaceStyle = .light
                window.enableTapToDismissKeyboard()
            }
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        for window in UIApplication.shared.connectedWindows {
            window.overrideUserInterfaceStyle = .light
            window.enableTapToDismissKeyboard()
        }
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in
                DispatchQueue.main.async {
                    PermissionManager.shared.refreshStatus()
                }
            }
        )

        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
