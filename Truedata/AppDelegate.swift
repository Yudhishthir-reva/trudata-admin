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
        fetchFCMToken()
        ConnectivityAlertManager.shared.registerBackgroundTasks()
        ConnectivityAlertManager.shared.start()
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
        ConnectivityAlertManager.shared.checkAndNotifyIfNeeded()
        if UserDefaultManager.shared.isUserLoggedIn {
            LocationManager.shared.syncTrackingState()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        ConnectivityAlertManager.shared.scheduleBackgroundChecks()
        if UserDefaultManager.shared.isUserLoggedIn {
            LocationManager.shared.syncTrackingState()
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

    private func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            #if DEBUG
            if let error {
                print("Failed to fetch FCM token: \(error.localizedDescription)")
            }
            #endif
            guard let token, !token.isEmpty else { return }
            DispatchQueue.main.async {
                self.storeFCMTokenIfNeeded(token)
            }
        }
    }

    private func storeFCMTokenIfNeeded(_ token: String) {
        guard UserDefaultManager.shared.fcmToken != token else { return }
        UserDefaultManager.shared.fcmToken = token
        NotificationCenter.default.post(
            name: .fcmTokenUpdated,
            object: nil,
            userInfo: ["token": token]
        )
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

        DispatchQueue.main.async {
            self.storeFCMTokenIfNeeded(fcmToken)
        }
    }
}

extension Notification.Name {
    static let fcmTokenUpdated = Notification.Name("FCMToken")
}
