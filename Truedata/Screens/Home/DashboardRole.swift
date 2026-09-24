//
//  DashboardRole.swift
//  Truedata
//

import Foundation

enum DashboardRole {

    static func normalized(_ role: String) -> String {
        role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Admin + Sales Manager see staff sales/collection columns (Android home + staff activities).
    static func canShowStaffAmountDetails(role: String) -> Bool {
        let value = normalized(role)
        return value == "admin" || value == "sales manager"
    }

    /// Admin, Sales Manager, and Accountant get the Controls operation tile.
    static func canShowControlsOperation(role: String) -> Bool {
        ["admin", "sales manager", "accountant"].contains(normalized(role))
    }

    /// Pending Cheques queue — Android `canManageRetailerPayments` (not sale person).
    static func canShowPendingChequesOperation(role: String) -> Bool {
        canManageRetailerPayments(role: role)
    }

    /// Admin + Sales Manager can edit state/city while selecting beat.
    static func canEditStateAndCity(role: String) -> Bool {
        let value = normalized(role)
        return value == "admin" || value == "sales manager"
    }

    /// Order insights staff filter — admin + sales manager only.
    static func canShowStaffFilter(role: String) -> Bool {
        let value = normalized(role)
        return value == "admin" || value == "sales manager"
    }

    /// Privileged roles: admin / sales manager / accountant (Android `privilegedRoles`).
    static func isPrivilegedRole(_ role: String) -> Bool {
        ["admin", "sales manager", "accountant"].contains(normalized(role))
    }

    /// Admin, Sales Manager, Accountant may see seller mobile / WhatsApp (Android `canViewSellerMobile`).
    static func canViewSellerMobile(role: String) -> Bool {
        isPrivilegedRole(role)
    }

    /// Settle approved cheques + retailer-app payment approvals (Android `canManageRetailerPayments`).
    static func canManageRetailerPayments(role: String) -> Bool {
        isPrivilegedRole(role)
    }

    /// Convenience for the logged-in user role from UserDefaults.
    static var currentUserCanViewSellerMobile: Bool {
        canViewSellerMobile(
            role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        )
    }

    static var currentUserCanManageRetailerPayments: Bool {
        canManageRetailerPayments(
            role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        )
    }

    /// Whether to hide My Area section (default false to show all components provided by API).
    static func shouldHideMyAreaSection(role: String) -> Bool {
        false
    }
}
