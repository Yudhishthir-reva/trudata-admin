//
//  LocationHelper.swift
//  Truedata
//

import Combine
import CoreLocation
import Foundation
import UIKit

struct LocationSnapshot {
    let latitude: Double
    let longitude: Double
    let address: String
    var capturedAt: Date = Date()
    var isFresh: Bool { abs(capturedAt.timeIntervalSinceNow) <= 60 }
}

final class LocationHelper: NSObject, ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var snapshot: LocationSnapshot?
    @Published private(set) var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var requestedAt = Date.distantPast
    private var resumeObserver: AnyCancellable?
    /// After the user taps Continue on the consent popover, skip re-prompting for the auth callback fetch.
    private var skipNextConsentPrompt = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        resumeObserver = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.snapshot != nil || self.isLoading else { return }
                self.performLocationRefresh()
            }
    }

    /// Fetches GPS after showing the custom Continue popover (every user-triggered call).
    func refreshLocation(
        reason: String = "TruDataa needs your current location to continue — for attendance, shop visits, or related updates."
    ) {
        Task { @MainActor in
            LocationConsentPresenter.shared.ask(message: reason) { [weak self] in
                self?.skipNextConsentPrompt = true
                self?.performLocationRefresh()
            }
        }
    }

    /// Silent refresh (no popover) — use only after consent already given or internal auth upgrade.
    func refreshLocationSilently() {
        performLocationRefresh()
    }

    private func performLocationRefresh() {
        snapshot = nil
        geocoder.cancelGeocode()
        isLoading = false
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            updateOnMain {
                self.errorMessage = "Enable Location Services and allow location access in Settings."
                self.snapshot = nil
            }
        case .authorizedAlways, .authorizedWhenInUse:
            fetchCurrentLocation()
        @unknown default:
            updateOnMain {
                self.errorMessage = "Unable to access location."
                self.snapshot = nil
            }
        }
    }

    private func fetchCurrentLocation() {
        guard locationManager.accuracyAuthorization == .fullAccuracy else {
            errorMessage = "Enable Precise Location in app Settings, then refresh location."
            return
        }
        CLLocationManager.checkServicesEnabled { [weak self] enabled in
            guard let self else { return }
            guard enabled else {
                self.errorMessage = "Enable device Location Services, then try again."
                return
            }
            self.isLoading = true
            self.errorMessage = nil
            self.requestedAt = Date()
            self.locationManager.requestLocation()
            let started = self.requestedAt
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                guard let self, self.isLoading, self.requestedAt == started else { return }
                self.geocoder.cancelGeocode()
                self.isLoading = false
                self.snapshot = nil
                self.errorMessage = "Location timed out. Check device Location Services and refresh."
            }
        }
    }

    private func resolveAddress(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            let address = Self.formattedAddress(from: placemarks?.first)
            self.updateOnMain {
                guard location.timestamp >= self.requestedAt.addingTimeInterval(-1),
                      self.locationManager.accuracyAuthorization == .fullAccuracy,
                      [.authorizedAlways, .authorizedWhenInUse].contains(self.locationManager.authorizationStatus) else {
                    self.snapshot = nil
                    self.isLoading = false
                    self.errorMessage = "Location requirements changed. Refresh your location."
                    return
                }
                self.snapshot = LocationSnapshot(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address,
                    capturedAt: location.timestamp
                )
                self.errorMessage = address.isEmpty
                    ? "Unable to get address. Please try refreshing location."
                    : nil
                self.isLoading = false
            }
        }
    }

    private func updateOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
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

extension LocationHelper: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        snapshot = nil
        isLoading = false
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if skipNextConsentPrompt {
                skipNextConsentPrompt = false
                performLocationRefresh()
            } else {
                // User granted from Settings / system UI without our popover — fetch silently.
                performLocationRefresh()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              location.timestamp >= requestedAt.addingTimeInterval(-1) else {
            isLoading = false
            snapshot = nil
            errorMessage = "Could not get a fresh location. Please refresh and try again."
            return
        }
        resolveAddress(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        updateOnMain {
            self.isLoading = false
            self.snapshot = nil
            self.errorMessage = "Unable to get location. Please try again."
        }
    }
}
