//
//  LocationHelper.swift
//  Truedata
//

import Combine
import CoreLocation
import Foundation

struct LocationSnapshot {
    let latitude: Double
    let longitude: Double
    let address: String
}

final class LocationHelper: NSObject, ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var snapshot: LocationSnapshot?
    @Published private(set) var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func refreshLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            updateOnMain {
                self.errorMessage = "Location services are disabled."
                self.snapshot = nil
            }
            return
        }

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            updateOnMain {
                self.errorMessage = "Location permission is required."
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
        updateOnMain {
            self.isLoading = true
            self.errorMessage = nil
        }
        locationManager.requestLocation()
    }

    private func resolveAddress(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            let address = Self.formattedAddress(from: placemarks?.first)
            self.updateOnMain {
                self.snapshot = LocationSnapshot(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address
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
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            refreshLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
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
