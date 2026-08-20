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

    /// Admin-facing roles use Operations instead of the My Area home section.
    static func shouldHideMyAreaSection(role: String) -> Bool {
        canShowControlsOperation(role: role)
    }
}
