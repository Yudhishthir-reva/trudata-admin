//
//  PermissionManager.swift
//  Truedata
//

import Combine
import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

final class PermissionManager: NSObject, ObservableObject {

    static let shared = PermissionManager()

    @Published private(set) var locationGranted = false
    @Published private(set) var locationServicesEnabled = false
    @Published private(set) var notificationGranted = false
    @Published var hasRequestedLocation = false

    var canShowDashboard: Bool {
        locationGranted && locationServicesEnabled
    }

    var needsNotificationPermission: Bool {
        if #available(iOS 10.0, *) {
            return !notificationGranted
        }
        return false
    }

    var isLocationPermanentlyDenied: Bool {
        guard hasRequestedLocation, !locationGranted else { return false }
        let status = CLLocationManager.authorizationStatus()
        return status == .denied || status == .restricted
    }

    private let locationManager = CLLocationManager()

    override private init() {
        super.init()
        locationManager.delegate = self
    }

    func refreshStatus() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        let status = CLLocationManager.authorizationStatus()
        locationGranted = status == .authorizedWhenInUse || status == .authorizedAlways

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermissions() {
        hasRequestedLocation = true
        locationManager.requestWhenInUseAuthorization()

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.notificationGranted = granted
                }
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func openLocationSettings() {
        openAppSettings()
    }
}

extension PermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshStatus()
    }
}
