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

    /// Pending Cheques queue — same roles as Controls (Android `PENDING_CHEQUES_OPERATION`).
    static func canShowPendingChequesOperation(role: String) -> Bool {
        canShowControlsOperation(role: role)
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

    /// Whether to hide My Area section (default false to show all components provided by API).
    static func shouldHideMyAreaSection(role: String) -> Bool {
        false
    }
}
