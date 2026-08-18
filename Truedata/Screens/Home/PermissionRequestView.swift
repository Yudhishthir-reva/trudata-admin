//
//  PermissionRequestView.swift
//  Truedata
//

import SwiftUI

struct PermissionRequestView: View {

    let isLocationPermanentlyDenied: Bool
    let showNotificationPermission: Bool
    let showLocationServicesDisabled: Bool
    let onGrantPermission: () -> Void
    let onOpenSettings: () -> Void
    let onEnableLocationServices: () -> Void

    var body: some View {
        ScrollView {
            VStack {
                Spacer(minLength: 24)

                VStack(spacing: 0) {
                    permissionIconCluster
                        .padding(.bottom, 16)

                    Text("Permissions Required")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "225EC2"))
                        .multilineTextAlignment(.center)

                    Text(isLocationPermanentlyDenied
                         ? "Please enable permissions from device settings."
                         : "Grant permissions for attendance tracking.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        PermissionRow(
                            systemImage: "location.fill",
                            title: "Location Access",
                            subtitle: "Required for attendance tracking",
                            isRequired: true,
                            tint: isLocationPermanentlyDenied ? AppTheme.errorRed : Color(hex: "EAB308")
                        )

                        if showNotificationPermission {
                            PermissionRow(
                                systemImage: "bell.fill",
                                title: "Notifications",
                                subtitle: "For attendance alerts",
                                isRequired: false,
                                tint: AppTheme.textMuted
                            )
                        }

                        if showLocationServicesDisabled {
                            PermissionRow(
                                systemImage: "location.slash.fill",
                                title: "GPS",
                                subtitle: "For location tracking",
                                isRequired: true,
                                tint: Color(hex: "EAB308")
                            )
                        }
                    }
                    .padding(.top, 20)

                    actionButton
                        .padding(.top, 20)

                    if isLocationPermanentlyDenied {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            Text("Permission denied. Enable manually in Settings.")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "EAB308"))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "EAB308").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 12)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isLocationPermanentlyDenied {
            PermissionActionButton(title: "Open Settings", color: AppTheme.errorRed, action: onOpenSettings)
        } else if showLocationServicesDisabled {
            PermissionActionButton(title: "Enable GPS", color: Color(hex: "EAB308"), action: onEnableLocationServices)
        } else {
            let title = showNotificationPermission ? "Grant Permissions" : "Grant Permission"
            PermissionActionButton(title: title, color: Color(hex: "225EC2"), action: onGrantPermission)
        }
    }

    private var permissionIconCluster: some View {
        ZStack {
            if showNotificationPermission {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "7C3AED"))
                    .offset(x: 26, y: 14)
            }

            Circle()
                .fill(Color(hex: "225EC2").opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "location.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "225EC2"))
                }

            if showLocationServicesDisabled {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "7C3AED"))
                    .offset(y: 24)
            }
        }
        .frame(width: 80, height: 80)
    }
}

private struct PermissionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let isRequired: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if isRequired {
                        Text("*")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.errorRed)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PermissionActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
