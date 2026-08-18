//
//  SellerContactActions.swift
//  Truedata
//

import SwiftUI
import UIKit

enum SellerContactActions {

    static func call(_ phoneNumber: String, completion: @escaping (Result<Void, SellerContactActionError>) -> Void) {
        guard let dialNumber = sanitizedPhoneNumber(phoneNumber),
              let url = URL(string: "tel://\(dialNumber)") else {
            completion(.failure(.phoneUnavailable))
            return
        }

        open(url, unavailableMessage: "Unable to open phone app.") { success in
            completion(success ? .success(()) : .failure(.appUnavailable("Unable to open phone app.")))
        }
    }

    static func openWhatsApp(_ phoneNumber: String, completion: @escaping (Result<Void, SellerContactActionError>) -> Void) {
        guard let whatsAppNumber = whatsAppNumber(from: phoneNumber) else {
            completion(.failure(.whatsAppUnavailable))
            return
        }

        let appURL = URL(string: "whatsapp://send?phone=\(whatsAppNumber)")
        let webURL = URL(string: "https://api.whatsapp.com/send?phone=\(whatsAppNumber)")

        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            open(appURL, unavailableMessage: "WhatsApp is not installed.") { success in
                completion(success ? .success(()) : .failure(.appUnavailable("WhatsApp is not installed.")))
            }
            return
        }

        guard let webURL else {
            completion(.failure(.whatsAppUnavailable))
            return
        }

        open(webURL, unavailableMessage: "WhatsApp is not installed.") { success in
            completion(success ? .success(()) : .failure(.appUnavailable("WhatsApp is not installed.")))
        }
    }

    static func sendEmail(_ email: String, subject: String = "Inquiry for Shop", completion: @escaping (Result<Void, SellerContactActionError>) -> Void) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmptyString, trimmed.contains("@") else {
            completion(.failure(.emailUnavailable))
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmed
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject)
        ]

        guard let url = components.url else {
            completion(.failure(.emailUnavailable))
            return
        }

        open(url, unavailableMessage: "No email app found.") { success in
            completion(success ? .success(()) : .failure(.appUnavailable("No email app found.")))
        }
    }

    static func openMap(
        latitude: String,
        longitude: String,
        address: String,
        label: String,
        completion: @escaping (Result<Void, SellerContactActionError>) -> Void
    ) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if let lat = Double(latitude),
           let lng = Double(longitude),
           lat != 0, lng != 0 {
            let encodedLabel = trimmedLabel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedLabel
            let appleMapsURL = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(encodedLabel)")
            let googleMapsURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")

            openPreferredMap(appleMapsURL: appleMapsURL, googleMapsURL: googleMapsURL, completion: completion)
            return
        }

        guard !trimmedAddress.isEmptyString else {
            completion(.failure(.locationUnavailable))
            return
        }

        let encodedAddress = trimmedAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedAddress
        let appleMapsURL = URL(string: "http://maps.apple.com/?q=\(encodedAddress)")
        let googleMapsURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)")

        openPreferredMap(appleMapsURL: appleMapsURL, googleMapsURL: googleMapsURL, completion: completion)
    }

    static func shareText(for profile: SellerProfileInfo) -> String {
        var parts: [String] = []

        if !profile.displayShopName.isEmptyString, profile.displayShopName != "Shop name not available" {
            parts.append("Shop: \(profile.displayShopName)")
        }
        if !profile.displayOwnerName.isEmptyString, profile.displayOwnerName != "Owner name not available" {
            parts.append("Owner: \(profile.displayOwnerName)")
        }
        if !profile.mobile.isEmptyString {
            parts.append("Phone: \(profile.mobile)")
        }
        if !profile.whatsappNo.isEmptyString {
            parts.append("WhatsApp: \(profile.whatsappNo)")
        }
        if !profile.email.isEmptyString {
            parts.append("Email: \(profile.email)")
        }
        if !profile.address.isEmptyString {
            parts.append("Address: \(profile.address)")
        }
        if !profile.beat.isEmptyString {
            parts.append("Beat: \(profile.beat)")
        }
        if let mapsLink = googleMapsLink(
            latitude: profile.latitude,
            longitude: profile.longitude,
            address: profile.address,
            label: profile.displayShopName
        ) {
            parts.append("Maps: \(mapsLink)")
        }

        return parts.joined(separator: "\n")
    }

    static func googleMapsLink(latitude: String, longitude: String, address: String, label: String) -> String? {
        if let lat = Double(latitude),
           let lng = Double(longitude),
           lat != 0, lng != 0 {
            let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? label
            return "https://maps.google.com/?q=\(lat),\(lng)(\(encodedLabel))"
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmptyString else { return nil }

        let encodedAddress = trimmedAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedAddress
        return "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)"
    }

    static func sanitizedPhoneNumber(_ phoneNumber: String) -> String? {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : digits
    }

    static func whatsAppNumber(from rawNumber: String) -> String? {
        let clean = rawNumber.filter(\.isNumber)
        guard !clean.isEmpty else { return nil }

        if clean.count == 10 {
            return "91\(clean)"
        }
        if clean.count == 12, clean.hasPrefix("91") {
            return clean
        }
        if clean.count == 13, clean.hasPrefix("091") {
            return String(clean.dropFirst())
        }
        return clean
    }

    private static func openPreferredMap(
        appleMapsURL: URL?,
        googleMapsURL: URL?,
        completion: @escaping (Result<Void, SellerContactActionError>) -> Void
    ) {
        if let appleMapsURL {
            open(appleMapsURL, unavailableMessage: "No map app found.") { success in
                if success {
                    completion(.success(()))
                    return
                }

                guard let googleMapsURL else {
                    completion(.failure(.locationUnavailable))
                    return
                }

                open(googleMapsURL, unavailableMessage: "No map app found.") { googleSuccess in
                    completion(
                        googleSuccess
                            ? .success(())
                            : .failure(.appUnavailable("No map app found."))
                    )
                }
            }
            return
        }

        guard let googleMapsURL else {
            completion(.failure(.locationUnavailable))
            return
        }

        open(googleMapsURL, unavailableMessage: "No map app found.") { success in
            completion(success ? .success(()) : .failure(.appUnavailable("No map app found.")))
        }
    }

    private static func open(
        _ url: URL,
        unavailableMessage: String,
        completion: @escaping (Bool) -> Void
    ) {
        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
