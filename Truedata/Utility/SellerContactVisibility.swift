//
//  SellerContactVisibility.swift
//  Truedata
//
//  Match Android SellerContactVisibility — only admin / sales manager / accountant
//  may see seller mobile or WhatsApp numbers in the app.
//

import Foundation

enum SellerContactVisibility {
    static var canViewSellerMobile: Bool {
        DashboardRole.currentUserCanViewSellerMobile
    }

    /// Cheque settlement + retailer-app payment approvals — sale persons don't get these.
    static var canManageRetailerPayments: Bool {
        DashboardRole.currentUserCanManageRetailerPayments
    }

    /// Returns the number when allowed and non-empty; otherwise nil (caller hides the row).
    static func visibleMobile(_ raw: String?) -> String? {
        guard canViewSellerMobile else { return nil }
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Display helper: number when allowed, otherwise `Hidden` / empty.
    static func displayMobile(_ raw: String?, hiddenPlaceholder: String = "Hidden") -> String {
        if let mobile = visibleMobile(raw) { return mobile }
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "-" }
        return canViewSellerMobile ? trimmed : hiddenPlaceholder
    }
}
