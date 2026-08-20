//
//  OperationsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum OperationsScreenType: String, Hashable, CaseIterable {
    case actions = "Actions"
    case seller = "Seller"
    case activity = "Activity"
    case controls = "Controls"

    var title: String { rawValue }

    var allowedRoutes: Set<String> {
        switch self {
        case .actions:
            return ["attendance", "regularization_requests", "apply_reimbursements", "view_leaves"]
        case .seller:
            return ["registered_sellers", "view_products"]
        case .activity:
            return ["today_achievements"]
        case .controls:
            return [
                "controls",
                "staff_report",
                "rider_report",
                "manage_employees",
                "leave_approval",
                "regularize_approval",
                "expense_approval"
            ]
        }
    }

    var routeOrder: [String] {
        switch self {
        case .actions:
            return ["attendance", "view_leaves", "regularization_requests", "apply_reimbursements"]
        case .seller:
            return ["registered_sellers", "view_products"]
        case .activity:
            return ["today_achievements"]
        case .controls:
            return [
                "leave_approval",
                "regularize_approval",
                "expense_approval",
                "controls",
                "staff_report",
                "rider_report",
                "manage_employees"
            ]
        }
    }
}

struct OperationsCardContent {
    let tile: OperationsTile
    let statusText: String
    let statusColor: Color
    let iconName: String
    let iconColor: Color
    let actionTitle: String

    static func make(from tile: OperationsTile) -> OperationsCardContent {
        switch tile.route {
        case "attendance":
            return attendanceContent(tile)
        case "view_leaves":
            return leavesContent(tile)
        case "regularization_requests":
            return regularizeContent(tile)
        case "apply_reimbursements":
            return expenseContent(tile)
        case "registered_sellers":
            return sellerContent(tile)
        case "view_products":
            return productsContent(tile)
        case "today_achievements":
            return achievementsContent(tile)
        default:
            return genericContent(tile)
        }
    }

    private static func attendanceContent(_ tile: OperationsTile) -> OperationsCardContent {
        let inTime = tile.payload?.string(for: "in_time") ?? ""
        let outTime = tile.payload?.string(for: "out_time") ?? ""
        let validIn = !inTime.isEmptyString && inTime != "No data available"
        let validOut = !outTime.isEmptyString && outTime != "No data available"

        let status: String
        let color: Color
        let icon: String
        if validIn && validOut {
            status = "Shift Complete"
            color = DashboardTheme.successGreen
            icon = "checkmark.circle.fill"
        } else if validIn {
            status = "Working"
            color = DashboardTheme.warningYellow
            icon = "clock.fill"
        } else {
            status = "Check In Pending"
            color = DashboardTheme.neutralDark
            icon = "arrow.right.to.line.compact"
        }

        return OperationsCardContent(
            tile: tile,
            statusText: status,
            statusColor: color,
            iconName: icon,
            iconColor: validIn && validOut ? DashboardTheme.successGreen : DashboardTheme.primaryBlue,
            actionTitle: "View Details"
        )
    }

    private static func leavesContent(_ tile: OperationsTile) -> OperationsCardContent {
        let total = tile.payload?.int(for: "totalLeaveCount") ?? 0
        let status = tile.payload?.string(for: "status") ?? ""
        let startDate = tile.payload?.string(for: "start_date") ?? ""

        let statusText: String
        if total == 0 {
            statusText = "No leaves"
        } else if !status.isEmptyString && !startDate.isEmptyString {
            statusText = status.capitalized
        } else {
            statusText = "\(total) leave(s)"
        }

        return OperationsCardContent(
            tile: tile,
            statusText: statusText,
            statusColor: total == 0 ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark,
            iconName: total == 0 ? "checkmark.circle" : "calendar.badge.clock",
            iconColor: DashboardTheme.successGreen,
            actionTitle: "View History"
        )
    }

    private static func regularizeContent(_ tile: OperationsTile) -> OperationsCardContent {
        let total = tile.payload?.int(for: "totalRegularizeCount", "allRegularizeCount") ?? 0
        let statusText = total == 0 ? "No requests" : "\(total) request(s)"

        return OperationsCardContent(
            tile: tile,
            statusText: statusText,
            statusColor: total == 0 ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark,
            iconName: "magnifyingglass.circle",
            iconColor: DashboardTheme.neutralMedium,
            actionTitle: "View Requests"
        )
    }

    private static func expenseContent(_ tile: OperationsTile) -> OperationsCardContent {
        let total = tile.payload?.int(for: "totalExpenseCount") ?? 0
        let statusText = total == 0 ? "No expenses" : "\(total) expense(s)"

        return OperationsCardContent(
            tile: tile,
            statusText: statusText,
            statusColor: total == 0 ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark,
            iconName: "indianrupeesign.circle",
            iconColor: DashboardTheme.secondaryPurple,
            actionTitle: "View Expenses"
        )
    }

    private static func sellerContent(_ tile: OperationsTile) -> OperationsCardContent {
        let total = tile.payload?.int(for: "totalSellerCount", "total_seller_count") ?? 0
        return OperationsCardContent(
            tile: tile,
            statusText: "\(total) sellers",
            statusColor: DashboardTheme.neutralDark,
            iconName: "storefront.fill",
            iconColor: DashboardTheme.accentTeal,
            actionTitle: "View All"
        )
    }

    private static func productsContent(_ tile: OperationsTile) -> OperationsCardContent {
        let total = tile.payload?.int(for: "allProducts", "all_products") ?? 0
        return OperationsCardContent(
            tile: tile,
            statusText: "\(total) products",
            statusColor: DashboardTheme.neutralDark,
            iconName: "shippingbox.fill",
            iconColor: DashboardTheme.infoBlue,
            actionTitle: "View Products"
        )
    }

    private static func achievementsContent(_ tile: OperationsTile) -> OperationsCardContent {
        let sellers = tile.payload?.int(for: "todaySellerCount", "today_seller_count") ?? 0
        return OperationsCardContent(
            tile: tile,
            statusText: "\(sellers) sellers today",
            statusColor: DashboardTheme.neutralDark,
            iconName: "chart.bar.fill",
            iconColor: DashboardTheme.primaryBlue,
            actionTitle: "View Details"
        )
    }

    private static func genericContent(_ tile: OperationsTile) -> OperationsCardContent {
        OperationsCardContent(
            tile: tile,
            statusText: "Available",
            statusColor: DashboardTheme.neutralMedium,
            iconName: "square.grid.2x2",
            iconColor: DashboardTheme.primaryBlue,
            actionTitle: "Open"
        )
    }
}

struct OperationsTile: Identifiable {
    let id: String
    let title: String
    let route: String
    let payload: JSONValue?

    init(item: DashboardItem) {
        id = item.id
        title = item.title
        route = item.route
        payload = item.payload
    }

    init(id: String, title: String, route: String, payload: JSONValue?) {
        self.id = id
        self.title = title
        self.route = route
        self.payload = payload
    }
}
