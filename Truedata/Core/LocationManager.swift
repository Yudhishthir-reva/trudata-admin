//
//  LocationManager.swift
//  Truedata
//

import Combine
import CoreLocation
import Foundation
import UIKit
import UserNotifications

final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let uploadService = LocationUploadServiceManager()
    private let trackingNotificationId = "location-tracking-active"

    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTrackingActive: Bool = false
    @Published private(set) var isLocationServiceEnabled: Bool = true
    @Published private(set) var errorMessage: String?

    private var singleLocationCompletion: ((CLLocation?) -> Void)?
    private var uploadWorkItem: DispatchWorkItem?
    private var captureTimeoutWorkItem: DispatchWorkItem?
    private var uploadCancellable: AnyCancellable?
    private var alwaysUpgradeWorkItem: DispatchWorkItem?
    private var trackingEngineRunning = false

    /// Exposed for BGTask scheduling (matches `location-config` interval).
    var configuredUploadInterval: TimeInterval { uploadInterval }

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        applyLocationConfig()
        refreshStatus()
    }

    // MARK: - Status

    func refreshStatus() {
        let servicesEnabled = CLLocationManager.locationServicesEnabled()
        let status = locationManager.authorizationStatus

        DispatchQueue.main.async {
            self.isLocationServiceEnabled = servicesEnabled
            self.authorizationStatus = status
        }
    }

    /// Reconcile tracking with server prefs (`service_enabled` + `is_user_working`).
    func syncTrackingState() {
        refreshStatus()
        if UserDefaultManager.shared.isLocationTrackingNeeded {
            startTrackingIfPossible()
        } else {
            stopShiftTracking()
        }
        ConnectivityAlertManager.shared.scheduleBackgroundChecks()
    }

    // MARK: - Permissions

    func requestPermissions() {
        refreshStatus()
        ensureAlwaysAuthorizationIfNeeded(openSettingsIfDenied: true)
    }

    /// Step-up flow: NotDetermined → WhenInUse → Always (Android always-location parity).
    private func ensureAlwaysAuthorizationIfNeeded(openSettingsIfDenied: Bool) {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            scheduleAlwaysUpgradeRequest()
        case .denied, .restricted:
            if openSettingsIfDenied {
                openAppSettings()
            }
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }

    private func scheduleAlwaysUpgradeRequest() {
        alwaysUpgradeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.locationManager.authorizationStatus == .authorizedWhenInUse else { return }
            self.locationManager.requestAlwaysAuthorization()
        }
        alwaysUpgradeWorkItem = work
        // Brief delay so the When-In-Use sheet can dismiss cleanly (Apple guidance).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Shift Tracking

    func startShiftTracking() {
        startTrackingIfPossible()
    }

    func stopShiftTracking() {
        uploadWorkItem?.cancel()
        uploadWorkItem = nil
        captureTimeoutWorkItem?.cancel()
        captureTimeoutWorkItem = nil
        uploadCancellable?.cancel()
        uploadCancellable = nil
        alwaysUpgradeWorkItem?.cancel()
        alwaysUpgradeWorkItem = nil
        singleLocationCompletion = nil

        locationManager.stopUpdatingLocation()
        clearTrackingActiveNotification()
        trackingEngineRunning = false

        DispatchQueue.main.async {
            self.isTrackingActive = false
        }
        #if DEBUG
        print("[LocationManager] Background tracking stopped.")
        #endif
    }

    /// Force one upload cycle while shift tracking is active (used by BGAppRefresh).
    func triggerUploadIfTracking() {
        guard trackingEngineRunning, UserDefaultManager.shared.isLocationTrackingNeeded else { return }
        processLocationUpload()
    }

    // MARK: - Single Location Fetch

    func getCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        if let current = lastLocation, abs(current.timestamp.timeIntervalSinceNow) < 15.0 {
            completion(current)
            return
        }

        singleLocationCompletion = completion
        locationManager.requestLocation()
    }

    // MARK: - Private

    private func startTrackingIfPossible() {
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.isLocationServiceEnabled = false
                self.errorMessage = "Location services are disabled on this device."
            }
            ConnectivityAlertManager.shared.checkAndNotifyIfNeeded()
            return
        }

        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            requestPermissions()
            return
        }

        // Prefer Always for true background shift tracking.
        if status == .authorizedWhenInUse {
            scheduleAlwaysUpgradeRequest()
        }

        applyLocationConfig()
        locationManager.allowsBackgroundLocationUpdates = (status == .authorizedAlways)
        locationManager.startUpdatingLocation()

        let alreadyActive = trackingEngineRunning
        trackingEngineRunning = true
        DispatchQueue.main.async {
            self.isTrackingActive = true
            self.errorMessage = nil
        }

        if !alreadyActive {
            showTrackingActiveNotification()
            scheduleNextUpload()
            // Kick an immediate upload so first ping is not delayed by full interval.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.processLocationUpload()
            }
        }

        ConnectivityAlertManager.shared.scheduleBackgroundChecks()

        #if DEBUG
        print("[LocationManager] Background shift tracking started (auth=\(status.rawValue)).")
        #endif
    }

    private func applyLocationConfig() {
        let priority = UserDefaultManager.shared.getUserDefaultsString(key: .locationPriority)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch priority {
        case "low":
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        case "high":
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        default:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
    }

    private var uploadInterval: TimeInterval {
        let raw = UserDefaultManager.shared.getUserDefaultsString(key: .locationUpdateInterval)
        let seconds = Double(raw) ?? 60
        return max(seconds, 15)
    }

    private func scheduleNextUpload() {
        guard trackingEngineRunning else { return }

        uploadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.processLocationUpload()
        }
        uploadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + uploadInterval, execute: work)
    }

    private func processLocationUpload() {
        guard trackingEngineRunning else { return }

        guard UserDefaultManager.shared.isLocationTrackingNeeded else {
            stopShiftTracking()
            return
        }

        ConnectivityAlertManager.shared.checkAndNotifyIfNeeded()

        fetchCurrentLocationForUpload { [weak self] location in
            guard let self else { return }
            if let location {
                self.uploadLocationToServer(location)
            }
            self.scheduleNextUpload()
        }
    }

    private func fetchCurrentLocationForUpload(completion: @escaping (CLLocation?) -> Void) {
        if let current = lastLocation, abs(current.timestamp.timeIntervalSinceNow) < 30 {
            completion(current)
            return
        }

        singleLocationCompletion = completion
        locationManager.requestLocation()

        captureTimeoutWorkItem?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, let pending = self.singleLocationCompletion else { return }
            self.singleLocationCompletion = nil
            pending(self.lastLocation)
        }
        captureTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeout)
    }

    private func uploadLocationToServer(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            let address = Self.formattedAddress(from: placemarks?.first)
            let batteryLevel = Self.batteryLevel()
            let accuracyMeter = String(format: "%.0f", location.horizontalAccuracy)
            let accuracyStatus = Self.accuracyStatus(for: location.horizontalAccuracy)

            self.uploadCancellable = self.uploadService.uploadLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: address.isEmpty ? "Address lookup failed" : address,
                batteryLevel: batteryLevel,
                accuracyMeter: accuracyMeter,
                accuracyStatus: accuracyStatus
            )
            .sink(
                receiveCompletion: { completion in
                    #if DEBUG
                    if case .failure(let error) = completion {
                        print("[LocationManager] add-location failed: \(error.localizedDescription)")
                    }
                    #endif
                },
                receiveValue: { _ in
                    #if DEBUG
                    print("[LocationManager] add-location uploaded successfully.")
                    #endif
                }
            )
        }
    }

    // MARK: - Tracking notification (Android foreground-service parity)

    private func showTrackingActiveNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Location Tracking Active"
        content.body = "TruDataa is tracking your location in background"
        content.sound = nil
        content.interruptionLevel = .passive
        content.threadIdentifier = "location-tracking"

        let request = UNNotificationRequest(
            identifier: trackingNotificationId,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func clearTrackingActiveNotification() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [trackingNotificationId])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [trackingNotificationId])
    }

    private static func batteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return -1 }
        return Int(level * 100)
    }

    private static func accuracyStatus(for accuracy: CLLocationAccuracy) -> String {
        guard accuracy >= 0 else { return "Unknown" }
        switch accuracy {
        case ...5:
            return "Excellent (±\(Int(accuracy))m)"
        case ...20:
            return "Very Good (±\(Int(accuracy))m)"
        case ...100:
            return "Good (±\(Int(accuracy))m)"
        case ...500:
            return "Fair (±\(Int(accuracy))m)"
        case ...1000:
            return "Poor (±\(Int(accuracy))m)"
        default:
            return "Very Poor (±\(Int(accuracy))m)"
        }
    }

    private static func formattedAddress(from placemark: CLPlacemark?) -> String {
        guard let placemark else { return "" }

        var parts: [String] = []
        if let subThoroughfare = placemark.subThoroughfare { parts.append(subThoroughfare) }
        if let thoroughfare = placemark.thoroughfare { parts.append(thoroughfare) }
        if let subLocality = placemark.subLocality { parts.append(subLocality) }
        if let locality = placemark.locality { parts.append(locality) }
        if let administrativeArea = placemark.administrativeArea { parts.append(administrativeArea) }
        if let postalCode = placemark.postalCode { parts.append(postalCode) }
        if let country = placemark.country { parts.append(country) }

        if parts.isEmpty {
            return [
                placemark.name,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isLocationServiceEnabled = CLLocationManager.locationServicesEnabled()
            PermissionManager.shared.refreshStatus()

            switch status {
            case .authorizedWhenInUse:
                self.scheduleAlwaysUpgradeRequest()
                if UserDefaultManager.shared.isLocationTrackingNeeded {
                    self.startTrackingIfPossible()
                }
            case .authorizedAlways:
                if UserDefaultManager.shared.isLocationTrackingNeeded {
                    self.startTrackingIfPossible()
                }
            case .denied, .restricted:
                if self.trackingEngineRunning {
                    self.stopShiftTracking()
                }
                ConnectivityAlertManager.shared.checkAndNotifyIfNeeded()
            default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if abs(location.timestamp.timeIntervalSinceNow) > 30 { return }

        DispatchQueue.main.async {
            self.lastLocation = location
            if let completion = self.singleLocationCompletion {
                self.singleLocationCompletion = nil
                self.captureTimeoutWorkItem?.cancel()
                self.captureTimeoutWorkItem = nil
                completion(location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[LocationManager] Location error: \(error.localizedDescription)")
        #endif
        DispatchQueue.main.async {
            if let completion = self.singleLocationCompletion {
                self.singleLocationCompletion = nil
                self.captureTimeoutWorkItem?.cancel()
                self.captureTimeoutWorkItem = nil
                completion(self.lastLocation)
            }
        }
    }
}
