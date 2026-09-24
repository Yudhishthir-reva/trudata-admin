//
//  LocationManager.swift
//  Truedata
//
//  App Store 2.5.4: no background location mode / continuous employee tracking.
//  Location is only captured while the app is in use (one-shot / When In Use).
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

    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTrackingActive: Bool = false
    @Published private(set) var isLocationServiceEnabled: Bool = true
    @Published private(set) var errorMessage: String?

    private var singleLocationCompletion: ((CLLocation?) -> Void)?
    private var captureTimeoutWorkItem: DispatchWorkItem?
    private var uploadCancellable: AnyCancellable?

    /// Kept for callers; background upload interval is unused on App Store builds.
    var configuredUploadInterval: TimeInterval { 60 }

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .other
        // App Store 2.5.4 — do not enable background location updates.
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.showsBackgroundLocationIndicator = false
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

    /// Previously reconciled shift background tracking. Now only ensures tracking is stopped.
    func syncTrackingState() {
        refreshStatus()
        stopShiftTracking()
        ConnectivityAlertManager.shared.scheduleBackgroundChecks()
    }

    // MARK: - Permissions

    func requestPermissions() {
        refreshStatus()
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            openAppSettings()
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Shift Tracking (disabled for App Store)

    /// No-op: continuous / background shift tracking removed for Guideline 2.5.4.
    func startShiftTracking() {
        stopShiftTracking()
        #if DEBUG
        print("[LocationManager] startShiftTracking ignored — background tracking disabled for App Store.")
        #endif
    }

    func stopShiftTracking() {
        captureTimeoutWorkItem?.cancel()
        captureTimeoutWorkItem = nil
        uploadCancellable?.cancel()
        uploadCancellable = nil
        locationManager.stopUpdatingLocation()

        DispatchQueue.main.async {
            self.isTrackingActive = false
        }
    }

    /// No-op: background refresh uploads removed for App Store.
    func triggerUploadIfTracking() {
        #if DEBUG
        print("[LocationManager] triggerUploadIfTracking ignored — background tracking disabled.")
        #endif
    }

    // MARK: - Single Location Fetch (foreground / When In Use)

    /// One-shot GPS read. By default shows the custom Continue popover first (user-triggered APIs).
    func getCurrentLocation(
        requiresUserConsent: Bool = true,
        reason: String = "TruDataa needs your current location to submit this request.",
        completion: @escaping (CLLocation?) -> Void
    ) {
        if requiresUserConsent {
            Task { @MainActor in
                LocationConsentPresenter.shared.ask(message: reason) { [weak self] in
                    self?.getCurrentLocation(requiresUserConsent: false, completion: completion)
                }
            }
            return
        }

        ensureWhenInUseAuthorizationIfNeeded()

        if let current = lastLocation, abs(current.timestamp.timeIntervalSinceNow) < 15.0 {
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

    private func ensureWhenInUseAuthorizationIfNeeded() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Helpers (kept for potential foreground one-off uploads)

    func uploadCurrentLocationOnceIfAvailable() {
        guard let location = lastLocation else { return }
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
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
        }
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
            case .denied, .restricted:
                self.stopShiftTracking()
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
