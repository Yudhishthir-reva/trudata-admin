//
//  OrderInsightsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

struct OrderInsightsResponse: Decodable {
    var status: Bool
    var message: String
    var data: OrderInsightsPayload

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(OrderInsightsPayload.self, forKey: .data)) ?? OrderInsightsPayload()
    }
}

struct OrderInsightsPayload: Decodable {
    var total: Int
    var summary: [OrderInsightsSummaryItem]
    var ordersPage: OrderInsightsOrdersPage
    var topSeller: OrderInsightsTopPerformer?
    var topStaff: OrderInsightsTopPerformer?
    var averageOrderValue: String

    enum CodingKeys: String, CodingKey {
        case total, summary
        case ordersPage = "data"
        case topSeller = "top_seller"
        case topStaff = "top_staff"
        case averageOrderValue = "average_order_value"
    }

    init(
        total: Int = 0,
        summary: [OrderInsightsSummaryItem] = [],
        ordersPage: OrderInsightsOrdersPage = OrderInsightsOrdersPage(),
        topSeller: OrderInsightsTopPerformer? = nil,
        topStaff: OrderInsightsTopPerformer? = nil,
        averageOrderValue: String = "0"
    ) {
        self.total = total
        self.summary = summary
        self.ordersPage = ordersPage
        self.topSeller = topSeller
        self.topStaff = topStaff
        self.averageOrderValue = averageOrderValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        summary = (try? container.decode([OrderInsightsSummaryItem].self, forKey: .summary)) ?? []
        ordersPage = (try? container.decode(OrderInsightsOrdersPage.self, forKey: .ordersPage))
            ?? OrderInsightsOrdersPage()
        topSeller = try? container.decode(OrderInsightsTopPerformer.self, forKey: .topSeller)
        topStaff = try? container.decode(OrderInsightsTopPerformer.self, forKey: .topStaff)
        averageOrderValue = container.decodeStringLeniently(forKey: .averageOrderValue) ?? "0"
    }
}

struct OrderInsightsOrdersPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var orders: [OrderInsightsOrder]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case orders = "data"
    }

    init(currentPage: Int = 0, lastPage: Int = 0, orders: [OrderInsightsOrder] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.orders = orders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        orders = (try? container.decode([OrderInsightsOrder].self, forKey: .orders)) ?? []
    }
}

struct OrderInsightsSummaryItem: Identifiable, Decodable {
    var id: String { status }
    var status: String
    var statusLabel: String
    var count: Int
    var totalAmount: Double

    enum CodingKeys: String, CodingKey {
        case status
        case statusLabel = "status_label"
        case count
        case totalAmount = "total_amount"
    }

    init(
        status: String = "",
        statusLabel: String = "",
        count: Int = 0,
        totalAmount: Double = 0
    ) {
        self.status = status
        self.statusLabel = statusLabel
        self.count = count
        self.totalAmount = totalAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusLabel = container.decodeStringLeniently(forKey: .statusLabel) ?? ""
        count = container.decodeIntLeniently(forKey: .count)
            ?? Int(container.decodeStringLeniently(forKey: .count) ?? "0")
            ?? 0
        if let amount = container.decodeDoubleLeniently(forKey: .totalAmount) {
            totalAmount = amount
        } else {
            totalAmount = Double(container.decodeStringLeniently(forKey: .totalAmount) ?? "0") ?? 0
        }
    }
}

struct OrderInsightsTopPerformer: Decodable {
    var id: String
    var name: String
    var amount: String

    enum CodingKeys: String, CodingKey {
        case id, name, amount
    }

    init(id: String = "", name: String = "", amount: String = "0") {
        self.id = id
        self.name = name
        self.amount = amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeStringLeniently(forKey: .id) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
    }
}

struct OrderInsightsOrder: Identifiable, Decodable {
    var id: Int
    var orderNo: String
    var sellerPhone: String
    var staffName: String
    var riderName: String
    var sellerName: String
    var beatName: String
    var totalAmount: String
    var status: String
    var orderDate: String
    var containsSpecialNote: Bool
    var showRedBox: Bool
    var orderNotDelivered: Bool
    var deliveryDateTime: String

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case orderNo = "order_no"
        case sellerPhone = "seller_mobile"
        case staffName = "staff_name"
        case riderName = "rider_name"
        case sellerName = "seller_shop_name"
        case sellerNameFallback = "seller_name"
        case beatName = "beat_name"
        case totalAmount = "total_price"
        case status
        case orderDate = "order_date"
        case containsSpecialNote = "contains_special_note"
        case showRedBox = "shop_visited_location_incorrect"
        case orderNotDelivered = "order_not_delivered"
        case deliveryDate
        case deliveryTime = "delivery_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerPhone = container.decodeStringLeniently(forKey: .sellerPhone) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        riderName = container.decodeStringLeniently(forKey: .riderName) ?? ""
        let shopName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        let fallbackName = container.decodeStringLeniently(forKey: .sellerNameFallback) ?? ""
        sellerName = shopName.isEmptyString ? fallbackName : shopName
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        totalAmount = container.decodeStringLeniently(forKey: .totalAmount) ?? "0"
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        containsSpecialNote = container.decodeBoolLeniently(forKey: .containsSpecialNote) ?? false
        showRedBox = container.decodeBoolLeniently(forKey: .showRedBox) ?? false
        orderNotDelivered = container.decodeBoolLeniently(forKey: .orderNotDelivered) ?? false

        let deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate)
        let deliveryTime = container.decodeStringLeniently(forKey: .deliveryTime)
        if let deliveryDate, !deliveryDate.isEmptyString {
            deliveryDateTime = [deliveryDate, deliveryTime ?? ""]
                .filter { !$0.isEmptyString }
                .joined(separator: " ")
        } else {
            deliveryDateTime = "Not Delivered Yet"
        }
    }
}

struct OrderInsightsStatusTab: Identifiable {
    let id: String
    let label: String
    let count: Int
}

enum OrderInsightsStatusStyle {
    case pending, toDeliver, pickup, delivered, cancelled, returned, assigned, deliveryFailed, partialReturn, unknown

    static func from(status: String) -> OrderInsightsStatusStyle {
        switch status.lowercased() {
        case "0", "pending": return .pending
        case "1", "to deliver": return .toDeliver
        case "2", "pickup": return .pickup
        case "3", "delivered": return .delivered
        case "4", "cancel", "cancelled": return .cancelled
        case "5", "return", "returned": return .returned
        case "6", "assign", "assigned": return .assigned
        case "7", "delivery failed": return .deliveryFailed
        case "8", "partial return", "partially returned": return .partialReturn
        default: return .unknown
        }
    }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .toDeliver: return "To Deliver"
        case .pickup: return "Pickup"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        case .returned: return "Returned"
        case .assigned: return "Assigned"
        case .deliveryFailed: return "Delivery Failed"
        case .partialReturn: return "Partially Returned"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .pending: return DashboardTheme.warningYellow
        case .toDeliver: return DashboardTheme.infoBlue
        case .pickup: return Color(hex: "FD7E14")
        case .delivered: return DashboardTheme.successGreen
        case .cancelled, .deliveryFailed: return DashboardTheme.dangerRed
        case .returned, .partialReturn: return DashboardTheme.secondaryPurple
        case .assigned: return DashboardTheme.primaryBlue
        case .unknown: return DashboardTheme.neutralMedium
        }
    }
}

// MARK: - Date & Filters

enum OrderInsightsViewMode: String, CaseIterable {
    case list = "List"
    case report = "Report"
}

enum OrderInsightsFilterCategory: String, CaseIterable {
    case dateRange = "Date Range"
    case orderStatus = "Order Status"
    case staff = "Staff"
    case seller = "Seller"
    case beat = "Beat"
    case moreOptions = "More Options"
}

enum OrderInsightsDatePreset: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case custom = "Custom"

    static func dateRange(for preset: OrderInsightsDatePreset) -> (start: String, end: String)? {
        let calendar = Calendar.current
        let today = Date()
        let api = OrderInsightsDateFormat.self

        switch preset {
        case .today:
            return (api.string(from: today), api.string(from: today))
        case .yesterday:
            guard let y = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
            return (api.string(from: y), api.string(from: y))
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return nil }
            return (api.string(from: monday), api.string(from: today))
        case .lastWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
                  let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday),
                  let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday) else { return nil }
            return (api.string(from: lastMonday), api.string(from: lastSunday))
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: today)
            guard let start = calendar.date(from: comps) else { return nil }
            return (api.string(from: start), api.string(from: today))
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: today) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: lastMonth)
            guard let start = calendar.date(from: comps),
                  let range = calendar.range(of: .day, in: .month, for: lastMonth),
                  let end = calendar.date(byAdding: .day, value: range.count - 1, to: start) else { return nil }
            return (api.string(from: start), api.string(from: end))
        case .thisYear:
            let year = calendar.component(.year, from: today)
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
            return (api.string(from: start), api.string(from: today))
        case .custom:
            return nil
        }
    }
}

enum OrderInsightsDateFormat {
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        if let date = apiFormatter.date(from: value.trim) { return date }
        return DashboardDateFormat.parse(value)
    }

    static func string(from date: Date) -> String {
        apiFormatter.string(from: date)
    }

    static var todayString: String {
        string(from: Date())
    }

    static func normalizedAPIString(from value: String) -> String {
        guard !value.isEmptyString else { return todayString }
        if let date = parse(value) { return string(from: date) }
        return value
    }
}

struct OrderInsightsStaffMember: Identifiable, Decodable {
    var id: Int
    var name: String
    var mobile: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile
    }

    init(id: Int = 0, name: String = "", mobile: String = "") {
        self.id = id
        self.name = name
        self.mobile = mobile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
    }
}

struct OrderInsightsStaffListResponse: Decodable {
    var status: Bool
    var data: [OrderInsightsStaffMember]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        data = (try? container.decode([OrderInsightsStaffMember].self, forKey: .data)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case status, data
    }
}

struct OrderInsightsSellerItem: Identifiable, Decodable {
    var id: Int
    var name: String
    var shopName: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case shopName = "shop_name"
    }

    var displayName: String {
        shopName.isEmptyString ? name : shopName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
    }
}

struct OrderInsightsSellerListResponse: Decodable {
    var status: Bool
    var message: String
    var data: OrderInsightsSellerPage

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(OrderInsightsSellerPage.self, forKey: .data)) ?? OrderInsightsSellerPage()
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
}

struct OrderInsightsSellerPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var sellers: [OrderInsightsSellerItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case sellers = "data"
    }

    init(currentPage: Int = 0, lastPage: Int = 0, sellers: [OrderInsightsSellerItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.sellers = sellers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        sellers = (try? container.decode([OrderInsightsSellerItem].self, forKey: .sellers)) ?? []
    }
}

struct OrderInsightsBeatArea: Identifiable, Decodable {
    var id: Int
    var name: String
    var cityId: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case cityId = "city_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        cityId = container.decodeStringLeniently(forKey: .cityId) ?? ""
    }
}

struct OrderInsightsCityArea: Identifiable, Decodable {
    var id: Int
    var name: String
    var beats: [OrderInsightsBeatArea]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        beats = (try? container.decode([OrderInsightsBeatArea].self, forKey: .beats)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, beats
    }
}

struct OrderInsightsStateArea: Identifiable, Decodable {
    var id: Int
    var name: String
    var cities: [OrderInsightsCityArea]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        cities = (try? container.decode([OrderInsightsCityArea].self, forKey: .cities)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cities
    }
}

struct OrderInsightsAllAreaResponse: Decodable {
    var status: Bool
    var states: [OrderInsightsStateArea]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let dataContainer = try? container.nestedContainer(keyedBy: AreaDataKey.self, forKey: .data) {
            states = (try? dataContainer.decode([OrderInsightsStateArea].self, forKey: .states)) ?? []
        } else {
            states = []
        }
    }

    private enum AreaDataKey: String, CodingKey {
        case states = "0"
    }
}

struct OrderInsightsAppliedFilters {
    var startDate: String
    var endDate: String
    var datePreset: OrderInsightsDatePreset
    var orderStatus: String
    var staffId: String
    var sellerId: String
    var beatId: String
    var outOfRangeIsShow: String
    var hasRemark: String
}

extension OrderInsightsOrder {
    var displayOrderNo: String {
        orderNo.hasPrefix("#") ? orderNo : "#\(orderNo)"
    }

    var displayRiderName: String {
        riderName.isEmptyString ? "not assigned" : riderName
    }
}
