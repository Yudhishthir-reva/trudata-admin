//
//  RemoteConfigManager.swift
//  Truedata
//
//  Firebase Remote Config — e.g. location consent popover soft vs hard.
//

import Combine
import FirebaseRemoteConfig
import Foundation

enum LocationConsentMode: String {
    case soft
    case hard

    static func parse(_ raw: String?) -> LocationConsentMode {
        // App Store 5.1.1(iv): never allow a dismissible / delayable pre-permission flow.
        // Remote Config soft is ignored — always proceed (hard).
        _ = raw
        return .hard
    }
}

@MainActor
final class RemoteConfigManager: ObservableObject {

    static let shared = RemoteConfigManager()

    /// Remote Config key (Firebase Console). Value is forced to hard for App Store compliance.
    static let locationConsentModeKey = "location_consent_POP"

    @Published private(set) var locationConsentMode: LocationConsentMode = .hard
    @Published private(set) var lastFetchStatus: String = "idle"

    private let remoteConfig = RemoteConfig.remoteConfig()
    private var hasConfigured = false

    private init() {}

    func configureAndFetch() {
        guard !hasConfigured else {
            fetch()
            return
        }
        hasConfigured = true

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings

        remoteConfig.setDefaults([
            Self.locationConsentModeKey: NSString(string: LocationConsentMode.hard.rawValue)
        ])

        applyValuesFromCache()
        fetch()
    }

    func fetch() {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastFetchStatus = "error: \(error.localizedDescription)"
                    #if DEBUG
                    print("[RemoteConfig] fetch failed: \(error.localizedDescription)")
                    #endif
                    self.applyValuesFromCache()
                    return
                }

                switch status {
                case .successFetchedFromRemote:
                    self.lastFetchStatus = "fetched"
                case .successUsingPreFetchedData:
                    self.lastFetchStatus = "cached"
                case .error:
                    self.lastFetchStatus = "activate_error"
                @unknown default:
                    self.lastFetchStatus = "unknown"
                }

                self.applyValuesFromCache()
            }
        }
    }

    private func applyValuesFromCache() {
        let raw = remoteConfig[Self.locationConsentModeKey].stringValue
        let mode = LocationConsentMode.parse(raw)
        locationConsentMode = mode
        LocationConsentPresenter.shared.updateMode(mode)

        #if DEBUG
        print("[RemoteConfig] \(Self.locationConsentModeKey) raw=\(raw ?? "nil") → enforced=\(mode.rawValue)")
        #endif
    }
}
