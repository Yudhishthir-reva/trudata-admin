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
    @Published private(set) var isAlwaysLocationGranted = false
    @Published private(set) var locationServicesEnabled = false
    @Published private(set) var notificationGranted = false
    @Published var hasRequestedLocation = false

    var canShowDashboard: Bool {
        locationGranted && locationServicesEnabled
    }

    var needsNotificationPermission: Bool {
        !notificationGranted
    }

    var isLocationPermanentlyDenied: Bool {
        let status = locationManager.authorizationStatus
        return status == .denied || status == .restricted
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    private let locationManager = CLLocationManager()

    override private init() {
        super.init()
        locationManager.delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        let servicesEnabled = CLLocationManager.locationServicesEnabled()
        let status = locationManager.authorizationStatus
        let granted = status == .authorizedWhenInUse || status == .authorizedAlways
        let alwaysGranted = status == .authorizedAlways

        DispatchQueue.main.async {
            self.locationServicesEnabled = servicesEnabled
            self.locationGranted = granted
            self.isAlwaysLocationGranted = alwaysGranted
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermissions() {
        hasRequestedLocation = true
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        } else if status == .denied || status == .restricted {
            openAppSettings()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationGranted = granted
            }
        }
    }

    func requestAlwaysLocationPermission() {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            openAppSettings()
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
