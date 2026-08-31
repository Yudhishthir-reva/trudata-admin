//
//  AppDelegate.swift
//  Truedata
//

import UIKit
import UserNotifications
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase Configuration
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

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

    // MARK: - APNs Device Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNs Device Token: \(token)")
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Receive notification while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        #if DEBUG
        print("Foreground Notification Payload: \(userInfo)")
        #endif
        completionHandler([.banner, .sound, .badge])
    }

    // Handle tapping on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        #if DEBUG
        print("Notification Tapped with Payload: \(userInfo)")
        #endif
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        #if DEBUG
        print("Firebase registration token (FCM): \(fcmToken)")
        #endif

        // Store FCM Token locally
        UserDefaultManager.shared.fcmToken = fcmToken

        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
}
