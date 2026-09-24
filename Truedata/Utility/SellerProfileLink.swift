//
//  SellerProfileLink.swift
//  Truedata
//
//  Match Android SellerProfileLink — open seller profile from any list/detail card.
//

import SwiftUI

enum SellerProfileLink {
    /// Usable seller id, or nil for blanks / zeros APIs send when there is no seller.
    static func resolvedId(_ sellerId: Any?) -> Int? {
        guard let sellerId else { return nil }

        if let intValue = sellerId as? Int {
            return intValue > 0 ? intValue : nil
        }
        if let int64 = sellerId as? Int64 {
            return int64 > 0 ? Int(int64) : nil
        }
        if let number = sellerId as? NSNumber {
            let value = number.intValue
            return value > 0 ? value : nil
        }

        let text = "\(sellerId)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !text.isEmpty, text != "0", text != "null" else { return nil }
        return Int(text).flatMap { $0 > 0 ? $0 : nil }
    }
}

private struct OpenSellerProfileKey: EnvironmentKey {
    static let defaultValue: ((Int) -> Void)? = nil
}

extension EnvironmentValues {
    /// When set (e.g. from Home), profile opens via callback; otherwise NavigationLink is used.
    var openSellerProfile: ((Int) -> Void)? {
        get { self[OpenSellerProfileKey.self] }
        set { self[OpenSellerProfileKey.self] = newValue }
    }
}

/// Explicit "View Seller Profile" action — renders nothing without a usable id.
struct ViewSellerProfileButton: View {
    let sellerId: Any?
    @Environment(\.openSellerProfile) private var openSellerProfile

    var body: some View {
        if let id = SellerProfileLink.resolvedId(sellerId) {
            Group {
                if let openSellerProfile {
                    Button {
                        openSellerProfile(id)
                    } label: {
                        labelContent
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        SellerProfileScreen(sellerId: id, usesNavigationStack: false)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        labelContent
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var labelContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("View Seller Profile")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(DashboardTheme.primaryBlue)
    }
}
