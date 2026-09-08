//
//  ConnectivityAlertManager.swift
//  Truedata
//

import BackgroundTasks
import CoreLocation
import Foundation
import UIKit
import UserNotifications

/// Android `ConnectivityAndLocationWorker` parity:
/// every ~15 minutes, alert if Location or Internet is off while logged in.
final class ConnectivityAlertManager {

    static let shared = ConnectivityAlertManager()

    static let connectivityTaskId = "com.reva.trudataa.connectivity-check"
    static let locationRefreshTaskId = "com.reva.trudataa.location-refresh"

    private let checkInterval: TimeInterval = 15 * 60
    private var timer: Timer?
    private let alertNotificationId = "connectivity-location-alert"

    private init() {}

    // MARK: - BGTask registration (call from didFinishLaunching)

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.connectivityTaskId,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleConnectivityBGTask(refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.locationRefreshTaskId,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleLocationRefreshBGTask(refreshTask)
        }
    }

    func start() {
        guard timer == nil else {
            scheduleBackgroundChecks()
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkAndNotifyIfNeeded()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkAndNotifyIfNeeded()
        }

        scheduleBackgroundChecks()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.connectivityTaskId)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.locationRefreshTaskId)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [alertNotificationId])
    }

    func scheduleBackgroundChecks() {
        scheduleConnectivityBGTask()
        scheduleLocationRefreshBGTask()
    }

    func checkAndNotifyIfNeeded() {
        guard UserDefaultManager.shared.isUserLoggedIn else { return }

        let locationOn = isLocationUsable
        let internetOn = NetworkMonitor.shared.isConnected

        guard !locationOn || !internetOn else {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [alertNotificationId])
            return
        }

        sendAlertNotification(locationOn: locationOn, internetOn: internetOn)
    }

    // MARK: - BG handlers

    private func handleConnectivityBGTask(_ task: BGAppRefreshTask) {
        scheduleConnectivityBGTask()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        checkAndNotifyIfNeeded()
        task.setTaskCompleted(success: true)
    }

    private func handleLocationRefreshBGTask(_ task: BGAppRefreshTask) {
        scheduleLocationRefreshBGTask()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard UserDefaultManager.shared.isUserLoggedIn else {
            task.setTaskCompleted(success: true)
            return
        }

        checkAndNotifyIfNeeded()
        DispatchQueue.main.async {
            LocationManager.shared.syncTrackingState()
            if UserDefaultManager.shared.isLocationTrackingNeeded {
                LocationManager.shared.triggerUploadIfTracking()
            }
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleConnectivityBGTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.connectivityTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: checkInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[ConnectivityAlert] Failed to schedule connectivity BG task: \(error)")
            #endif
        }
    }

    private func scheduleLocationRefreshBGTask() {
        guard UserDefaultManager.shared.isUserLoggedIn,
              UserDefaultManager.shared.isLocationTrackingNeeded else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.locationRefreshTaskId)
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.locationRefreshTaskId)
        let interval = max(LocationManager.shared.configuredUploadInterval, 60)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[ConnectivityAlert] Failed to schedule location BG task: \(error)")
            #endif
        }
    }

    // MARK: - Checks / alerts

    private var isLocationUsable: Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        let status = LocationManager.shared.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    private func sendAlertNotification(locationOn: Bool, internetOn: Bool) {
        var messageParts: [String] = []
        if !locationOn {
            messageParts.append("Please turn on your Location. / कृपया अपना लोकेशन चालू करें।")
        }
        if !internetOn {
            messageParts.append("Please turn on your Internet. / कृपया अपना इंटरनेट चालू करें।")
        }

        let message = messageParts.joined(separator: "\n")
        let content = UNMutableNotificationContent()
        content.title = "Alert / चेतावनी"
        content.body = message
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: alertNotificationId,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
