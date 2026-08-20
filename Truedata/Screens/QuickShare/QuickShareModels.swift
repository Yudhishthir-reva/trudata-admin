//
//  QuickShareModels.swift
//  Truedata
//

import Foundation

enum QuickShareViewMode: String, CaseIterable, Identifiable {
    case exportAll = "Export All"
    case selectOrders = "Select Orders"

    var id: String { rawValue }
}

enum QuickShareFilterSection: String, CaseIterable, Identifiable {
    case staff = "Staff"
    case seller = "Seller"
    case orderStatus = "Order Status"

    var id: String { rawValue }
}

struct QuickShareOrderStatusOption: Identifiable, Hashable {
    let id: String
    let label: String

    static let allOptions: [QuickShareOrderStatusOption] = [
        QuickShareOrderStatusOption(id: "", label: "All Orders"),
        QuickShareOrderStatusOption(id: "0", label: "Pending"),
        QuickShareOrderStatusOption(id: "1", label: "To Deliver"),
        QuickShareOrderStatusOption(id: "2", label: "Pickup"),
        QuickShareOrderStatusOption(id: "3", label: "Delivered"),
        QuickShareOrderStatusOption(id: "4", label: "Cancelled"),
        QuickShareOrderStatusOption(id: "5", label: "Returned"),
        QuickShareOrderStatusOption(id: "6", label: "Assigned")
    ]
}
