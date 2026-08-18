//
//  DashboardCardStyles.swift
//  Truedata
//

import SwiftUI

enum DashboardTheme {
    static let primaryBlue = Color(hex: "225EC2")
    static let secondaryPurple = Color(hex: "7C3AED")
    static let accentTeal = Color(hex: "0891B2")
    static let infoBlue = Color(hex: "3B82F6")
    static let successGreen = Color(hex: "10B981")
    static let warningYellow = Color(hex: "EAB308")
    static let dangerRed = Color(hex: "EF4444")
    static let pickupOrange = Color(hex: "F97316")
    static let neutralDark = Color(hex: "1F2937")
    static let neutralMedium = Color(hex: "6B7280")
    static let surfaceVariant = Color(hex: "F3F4F6")
}

struct DashboardCardChrome<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 8, y: 2)
    }
}

struct DashboardBulletTitle: View {
    let title: String
    var colors: [Color] = [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple]
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 6, height: 6)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
        }
    }
}

struct DashboardPendingTag: View {
    let count: Int
    let suffix: String
    var systemImage: String = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.warningYellow)
            Text("\(count) \(suffix)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
    }
}

struct DashboardCompactButton: View {
    let title: String
    var color: Color = DashboardTheme.primaryBlue
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct DashboardOutlinedButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DashboardTheme.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardActionRowCard: View {
    let title: String
    let pendingCount: Int
    let pendingSuffix: String
    let buttonTitle: String
    var bulletColors: [Color] = [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple]
    var statusIcon: String = "exclamationmark.triangle.fill"
    var emptyText: String = "All Done"
    var action: () -> Void = {}

    var body: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardBulletTitle(title: title, colors: bulletColors)

                if pendingCount > 0 {
                    HStack(spacing: 8) {
                        DashboardPendingTag(count: pendingCount, suffix: pendingSuffix, systemImage: statusIcon)
                        Spacer(minLength: 0)
                        DashboardCompactButton(title: buttonTitle, action: action)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DashboardTheme.successGreen)
                        Text(emptyText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
        }
    }
}

struct DashboardStatPill: View {
    let title: String
    let value: String
    var valueColor: Color = DashboardTheme.neutralDark

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(valueColor)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(valueColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct DashboardSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(DashboardTheme.neutralDark)
    }
}

struct DashboardAmountTile: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value.currencyLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DashboardLegendRow: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
    }
}

extension Double {
    var currencyLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: self)) ?? "0"
        return "₹\(text)"
    }

    var compactCurrencyLabel: String {
        if self >= 1000 {
            let compact = self / 1000
            let formatted = compact.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", compact)
                : String(format: "%.1f", compact)
            return "₹\(formatted)k"
        }
        return currencyLabel
    }
}

extension JSONValue {
    func firstObject(in keys: [String]) -> [String: JSONValue]? {
        for key in keys {
            if let object = self[key]?.objectValue, !object.isEmpty { return object }
        }
        return nil
    }

    func int(for keys: String...) -> Int {
        for key in keys {
            if let value = self[key] { return value.intValue }
        }
        return 0
    }

    func double(for keys: String...) -> Double {
        for key in keys {
            if let value = self[key] { return value.doubleValue }
        }
        return 0
    }

    func string(for keys: String...) -> String {
        for key in keys {
            if let value = self[key]?.stringValue, !value.isEmptyString { return value }
        }
        return ""
    }
}
