//
//  LocationConsentPresenter.swift
//  Truedata
//
//  Pre-location prompt (Continue) before GPS / system permission.
//  App Store 5.1.1(iv): no "Not Now", no backdrop dismiss — Continue always
//  proceeds to the system permission prompt (or Open Settings if denied).
//

import Combine
import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class LocationConsentPresenter: NSObject, ObservableObject {

    static let shared = LocationConsentPresenter()

    @Published private(set) var isPresented = false
    @Published private(set) var title = "Location Access"
    @Published private(set) var message =
        "TruDataa uses your current location for this action — for example attendance punch, shop registration, or order updates."
    @Published private(set) var isWaitingForPermission = false
    /// After system deny / services off — show Settings CTA.
    @Published private(set) var needsOpenSettings = false

    private var pendingAction: (() -> Void)?
    private var isProcessingContinue = false
    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Kept for Remote Config compatibility; App Store flow always proceeds (hard).
    func updateMode(_ mode: LocationConsentMode) {
        _ = mode
    }

    /// Shows the custom popover; Continue always leads to system permission / Settings.
    func ask(
        title: String = "Location Access",
        message: String = "TruDataa uses your current location for this action — for example attendance punch, shop registration, or order updates.",
        proceed: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.pendingAction = proceed
        self.isWaitingForPermission = false
        self.needsOpenSettings = isLocationDeniedOrRestricted
        if needsOpenSettings {
            self.message = "Location permission is required. Enable it in Settings to continue."
        }
        self.isPresented = true
    }

    func continueTapped() {
        guard !isProcessingContinue else { return }
        isProcessingContinue = true
        defer { isProcessingContinue = false }

        guard CLLocationManager.locationServicesEnabled() else {
            needsOpenSettings = true
            message = "Turn on Location Services in Settings to continue."
            return
        }

        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // Already allowed — run the location action.
            dismissAndRunPending()
        case .notDetermined:
            // Always show the system permission prompt after Continue.
            isWaitingForPermission = true
            needsOpenSettings = false
            message = "Please allow location access on the next system prompt to continue."
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            needsOpenSettings = true
            isWaitingForPermission = false
            message = "Location permission is required. Enable it in Settings to continue."
            openSettings()
        @unknown default:
            needsOpenSettings = true
            message = "Unable to access location. Please enable it in Settings."
        }
    }

    func openSettingsTapped() {
        openSettings()
    }

    /// Call when app returns to foreground (Settings may have changed).
    func refreshHardGateIfNeeded() {
        guard isPresented else { return }
        evaluateAuthorization(status: locationManager.authorizationStatus)
    }

    private var isLocationDeniedOrRestricted: Bool {
        let status = locationManager.authorizationStatus
        return status == .denied || status == .restricted || !CLLocationManager.locationServicesEnabled()
    }

    private func dismissAndRunPending() {
        let action = pendingAction
        pendingAction = nil
        isWaitingForPermission = false
        needsOpenSettings = false
        isPresented = false
        action?()
    }

    private func evaluateAuthorization(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            dismissAndRunPending()
        case .denied, .restricted:
            needsOpenSettings = true
            isWaitingForPermission = false
            message = "Location permission is required. Enable it in Settings to continue."
        case .notDetermined:
            needsOpenSettings = false
        @unknown default:
            break
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension LocationConsentPresenter: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.isPresented else { return }
            self.evaluateAuthorization(status: status)
        }
    }
}

struct LocationConsentPopoverOverlay: View {
    @ObservedObject private var presenter = LocationConsentPresenter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if presenter.isPresented {
            ZStack {
                // Non-dismissible scrim (App Store 5.1.1(iv) — no delay / skip).
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(DashboardTheme.primaryBlue.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "location.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    Text(presenter.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))
                        .multilineTextAlignment(.center)

                    Text(presenter.message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if presenter.isWaitingForPermission {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                    }

                    Button {
                        if presenter.needsOpenSettings {
                            presenter.openSettingsTapped()
                        } else {
                            presenter.continueTapped()
                        }
                    } label: {
                        Text(presenter.needsOpenSettings ? "Open Settings" : "Continue")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DashboardTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(presenter.isWaitingForPermission && !presenter.needsOpenSettings)
                }
                .padding(20)
                .frame(maxWidth: 340)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 20, y: 8)
                .padding(.horizontal, 28)
            }
            .transition(.opacity)
            .zIndex(999)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    presenter.refreshHardGateIfNeeded()
                }
            }
        }
    }
}

extension View {
    /// Hosts the global location consent popover above the current hierarchy.
    func locationConsentPopoverHost() -> some View {
        ZStack {
            self
            LocationConsentPopoverOverlay()
        }
    }
}
