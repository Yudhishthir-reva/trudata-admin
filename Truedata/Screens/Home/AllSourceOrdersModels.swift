//
//  AllSourceOrdersModels.swift
//  Truedata
//
//  Matches Android `V2/all-order-list` (AllOrderListDto).
//

import Foundation
import SwiftUI

// MARK: - Source

enum AllSourceOrderSource: String, CaseIterable, Identifiable, Hashable {
    case all = ""
    case b2b = "b2b"
    case salesPerson = "sales_person"
    case b2c = "b2c"

    var id: String { rawValue.isEmpty ? "all" : rawValue }

    var tabLabel: String {
        switch self {
        case .all: return "All"
        case .b2b: return "B2B"
        case .salesPerson: return "Sales"
        case .b2c: return "B2C"
        }
    }

    var filterLabel: String {
        switch self {
        case .all: return "All sources"
        case .b2b: return "B2B"
        case .salesPerson: return "Sales Person"
        case .b2c: return "B2C"
        }
    }

    var filterDescription: String {
        switch self {
        case .all: return "Every order from every channel"
        case .b2b: return "Retailer + salesperson B2B orders"
        case .salesPerson: return "Only salesperson-placed orders"
        case .b2c: return "Customer (B2C) orders"
        }
    }

    var chipColor: Color {
        switch self {
        case .all: return DashboardTheme.primaryBlue
        case .b2b: return Color(hex: "2563EB")
        case .salesPerson: return Color(hex: "7C3AED")
        case .b2c: return Color(hex: "EA580C")
        }
    }

    static func fromAPI(_ value: String?) -> AllSourceOrderSource {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .all }
        return AllSourceOrderSource(rawValue: trimmed.lowercased()) ?? .b2b
    }
}

// MARK: - Date preset

enum AllSourceOrdersDatePreset: String, CaseIterable, Identifiable, Hashable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case thisFinancialYear = "This Financial Year"
    case lastFinancialYear = "Last Financial Year"
    case custom = "Custom"

    var id: String { rawValue }

    static let `default`: AllSourceOrdersDatePreset = .today

    static func dateRange(for preset: AllSourceOrdersDatePreset) -> (start: String, end: String)? {
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
        case .thisFinancialYear:
            return financialYearRange(offsetYears: 0, calendar: calendar, today: today, api: api)
        case .lastFinancialYear:
            return financialYearRange(offsetYears: -1, calendar: calendar, today: today, api: api, endAtToday: false)
        case .custom:
            return nil
        }
    }

    private static func financialYearRange(
        offsetYears: Int,
        calendar: Calendar,
        today: Date,
        api: OrderInsightsDateFormat.Type,
        endAtToday: Bool = true
    ) -> (start: String, end: String)? {
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        let fyStartYear = (month >= 4 ? year : year - 1) + offsetYears
        guard let start = calendar.date(from: DateComponents(year: fyStartYear, month: 4, day: 1)) else { return nil }
        if endAtToday && offsetYears == 0 {
            return (api.string(from: start), api.string(from: today))
        }
        guard let end = calendar.date(from: DateComponents(year: fyStartYear + 1, month: 3, day: 31)) else { return nil }
        return (api.string(from: start), api.string(from: end))
    }
}

// MARK: - Filter

struct AllSourceOrdersFilter: Equatable {
    var source: AllSourceOrderSource = .all
    var preset: AllSourceOrdersDatePreset = .default
    var startDate: String
    var endDate: String

    init(
        source: AllSourceOrderSource = .all,
        preset: AllSourceOrdersDatePreset = .default,
        startDate: String? = nil,
        endDate: String? = nil
    ) {
        self.source = source
        self.preset = preset
        if let startDate, let endDate {
            self.startDate = startDate
            self.endDate = endDate
        } else if let range = AllSourceOrdersDatePreset.dateRange(for: preset) {
            self.startDate = range.start
            self.endDate = range.end
        } else {
            let today = OrderInsightsDateFormat.todayString
            self.startDate = today
            self.endDate = today
        }
    }

    var activeCount: Int {
        [source != .all, preset != .default].filter(\.self).count
    }

    var dateChipLabel: String {
        if preset == .custom {
            return "\(startDate) → \(endDate)"
        }
        return preset.rawValue
    }
}

// MARK: - API models

struct AllSourceOrdersResponse: Decodable {
    var status: Bool
    var message: String
    var data: AllSourceOrdersPage

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let value = try? container.decode(JSONValue.self, forKey: .message) {
            switch value {
            case .array(let items):
                message = items.map(\.stringValue).filter { !$0.isEmpty }.joined(separator: "\n")
            default:
                message = value.stringValue
            }
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(AllSourceOrdersPage.self, forKey: .data)) ?? AllSourceOrdersPage()
    }
}

struct AllSourceOrdersPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var perPage: Int
    var total: Int
    var orders: [AllSourceOrderItem]
    var summary: [AllSourceOrderStatusSummary]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
        case data
        case summary
    }

    init(
        currentPage: Int = 1,
        lastPage: Int = 1,
        perPage: Int = 20,
        total: Int = 0,
        orders: [AllSourceOrderItem] = [],
        summary: [AllSourceOrderStatusSummary] = []
    ) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.perPage = perPage
        self.total = total
        self.orders = orders
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 20
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        orders = (try? container.decode([AllSourceOrderItem].self, forKey: .data)) ?? []
        summary = (try? container.decode([AllSourceOrderStatusSummary].self, forKey: .summary)) ?? []
    }
}

struct AllSourceOrderItem: Identifiable, Decodable, Hashable {
    var orderId: Int
    var orderNo: String
    var orderSource: String
    var orderSourceLabel: String
    var sellerName: String
    var sellerMobile: String
    var staffName: String
    var totalPrice: String
    var status: Int
    var statusLabel: String
    var paymentStatus: String
    var orderDate: String
    var invoiceLink: String?

    var id: String { "\(orderSource)-\(orderId)-\(orderNo)" }

    var source: AllSourceOrderSource { AllSourceOrderSource.fromAPI(orderSource) }

    var isB2C: Bool { source == .b2c }

    var displaySourceLabel: String {
        orderSourceLabel.isEmptyString ? source.filterLabel : orderSourceLabel
    }

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case orderSource = "order_source"
        case orderSourceLabel = "order_source_label"
        case sellerName = "seller_name"
        case sellerMobile = "seller_mobile"
        case staffName = "staff_name"
        case totalPrice = "total_price"
        case status
        case statusLabel = "status_label"
        case paymentStatus = "payment_status"
        case orderDate = "order_date"
        case invoiceLink = "invoice_link"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        orderSource = container.decodeStringLeniently(forKey: .orderSource) ?? ""
        orderSourceLabel = container.decodeStringLeniently(forKey: .orderSourceLabel) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        sellerMobile = container.decodeStringLeniently(forKey: .sellerMobile) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        status = container.decodeIntLeniently(forKey: .status) ?? 0
        statusLabel = container.decodeStringLeniently(forKey: .statusLabel) ?? ""
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        invoiceLink = container.decodeStringLeniently(forKey: .invoiceLink)
    }
}

struct AllSourceOrderStatusSummary: Identifiable, Decodable, Hashable {
    var status: String
    var statusLabel: String
    var count: String
    var totalAmount: String

    var id: String { status }

    var statusCode: Int { Int(status) ?? -1 }
    var countValue: Int { Int(count) ?? 0 }
    var amountValue: Double {
        Double(totalAmount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case status
        case statusLabel = "status_label"
        case count
        case totalAmount = "total_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusLabel = container.decodeStringLeniently(forKey: .statusLabel) ?? ""
        count = container.decodeStringLeniently(forKey: .count) ?? "0"
        totalAmount = container.decodeStringLeniently(forKey: .totalAmount) ?? "0"
    }
}

// MARK: - Summary hero math (Android OverviewContent)

struct AllSourceOrdersSummaryMetrics {
    let totalCount: Int
    let grossValue: Double
    let deliveredValue: Double
    let openValue: Double
    let cancelledCount: Int

    init(summary: [AllSourceOrderStatusSummary]) {
        totalCount = summary.reduce(0) { $0 + $1.countValue }
        grossValue = Self.amount(of: [0, 1, 2, 3, 6, 7, 8], in: summary)
        deliveredValue = Self.amount(of: [3, 8], in: summary)
        openValue = Self.amount(of: [0, 1, 2, 6], in: summary)
        cancelledCount = Self.count(of: [4, 5, 7], in: summary)
    }

    private static func amount(of codes: [Int], in summary: [AllSourceOrderStatusSummary]) -> Double {
        summary.filter { codes.contains($0.statusCode) }.reduce(0) { $0 + $1.amountValue }
    }

    private static func count(of codes: [Int], in summary: [AllSourceOrderStatusSummary]) -> Int {
        summary.filter { codes.contains($0.statusCode) }.reduce(0) { $0 + $1.countValue }
    }
}

enum AllSourceOrderStatusStyle {
    static func color(for status: Int) -> Color {
        switch status {
        case 0, 1: return DashboardTheme.warningYellow
        case 2, 6: return DashboardTheme.infoBlue
        case 3, 8: return DashboardTheme.successGreen
        case 4, 5, 7: return DashboardTheme.dangerRed
        default: return DashboardTheme.neutralMedium
        }
    }
}
