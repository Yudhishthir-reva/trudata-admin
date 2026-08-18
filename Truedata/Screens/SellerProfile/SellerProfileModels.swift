//
//  SellerProfileModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum SellerProfileDatePreset: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisYear
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisYear: return "This Year"
        case .custom: return "Custom"
        }
    }

    func dateRange(calendar: Calendar = .current) -> (start: String, end: String) {
        let today = calendar.startOfDay(for: Date())
        let formatter = SellerProfileDateFormat.apiFormatter

        switch self {
        case .today:
            let value = formatter.string(from: today)
            return (value, value)
        case .yesterday:
            let day = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let value = formatter.string(from: day)
            return (value, value)
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: today)
            let distance = (weekday + 5) % 7
            let start = calendar.date(byAdding: .day, value: -distance, to: today) ?? today
            return (formatter.string(from: start), formatter.string(from: today))
        case .lastWeek:
            let weekday = calendar.component(.weekday, from: today)
            let distance = (weekday + 5) % 7
            let thisWeekStart = calendar.date(byAdding: .day, value: -distance, to: today) ?? today
            let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: thisWeekStart) ?? today
            let lastWeekStart = calendar.date(byAdding: .day, value: -6, to: lastWeekEnd) ?? lastWeekEnd
            return (formatter.string(from: lastWeekStart), formatter.string(from: lastWeekEnd))
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: components) ?? today
            return (formatter.string(from: start), formatter.string(from: today))
        case .lastMonth:
            let thisMonth = calendar.dateComponents([.year, .month], from: today)
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let lastMonth = calendar.dateComponents([.year, .month], from: lastMonthDate)
            let start = calendar.date(from: lastMonth) ?? lastMonthDate
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
            _ = thisMonth
            return (formatter.string(from: start), formatter.string(from: end))
        case .thisYear:
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            return (formatter.string(from: start), formatter.string(from: today))
        case .custom:
            let value = formatter.string(from: today)
            return (value, value)
        }
    }
}

enum SellerProfileDateFormat {
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum SellerProfileTab: Int, CaseIterable, Identifiable {
    case stats = 0
    case actions = 1
    case orders = 2
    case payments = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .stats: return "Profile & Stats"
        case .actions: return "Actions"
        case .orders: return "Orders"
        case .payments: return "Payments"
        }
    }
}

struct SellerProfileResponse: Decodable {
    var status: Bool
    var message: String
    var canCreateOrder: Bool
    var data: SellerProfileData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case canCreateOrder = "can_create_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        canCreateOrder = container.decodeBoolLeniently(forKey: .canCreateOrder) ?? false
        data = try? container.decode(SellerProfileData.self, forKey: .data)
    }
}

struct SellerProfileData: Decodable {
    var profile: SellerProfileInfo?
    var financialStats: SellerProfileFinancialStats?
    var orderDistribution: SellerProfileOrderDistribution?
    var paymentMode: SellerProfilePaymentModeCounts?
    var paymentModeAmount: SellerProfilePaymentModeAmounts?
    var topCategories: [SellerProfileTopCategory]
    var topProducts: [SellerProfileTopProduct]

    enum CodingKeys: String, CodingKey {
        case profile
        case financialStats = "financial_stats"
        case orderDistribution = "order_distribution"
        case paymentMode = "payment_mode"
        case paymentModeAmount = "payment_mode_amount"
        case topCategories = "top_categories"
        case topProducts = "top_products"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try? container.decode(SellerProfileInfo.self, forKey: .profile)
        financialStats = try? container.decode(SellerProfileFinancialStats.self, forKey: .financialStats)
        orderDistribution = try? container.decode(SellerProfileOrderDistribution.self, forKey: .orderDistribution)
        paymentMode = try? container.decode(SellerProfilePaymentModeCounts.self, forKey: .paymentMode)
        paymentModeAmount = try? container.decode(SellerProfilePaymentModeAmounts.self, forKey: .paymentModeAmount)
        topCategories = (try? container.decode([SellerProfileTopCategory].self, forKey: .topCategories)) ?? []
        topProducts = (try? container.decode([SellerProfileTopProduct].self, forKey: .topProducts)) ?? []
    }
}

struct SellerProfileInfo: Decodable {
    var id: Int
    var name: String
    var email: String
    var shopName: String
    var landmark: String
    var latitude: String
    var longitude: String
    var sellerId: String
    var mobile: String
    var whatsappNo: String
    var status: String
    var profilePic: String
    var city: String
    var state: String
    var address: String
    var beat: String
    var manualAddress: String
    var colorId: Int?
    var colorDescription: String?
    var isShareSeller: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email, landmark, latitude, longitude, mobile, status, city, state, address, beat
        case shopName = "shop_name"
        case sellerId = "seller_id"
        case whatsappNo = "whatsapp_no"
        case profilePic = "profile_pic"
        case manualAddress = "manual_address"
        case colorId = "color_id"
        case colorDescription = "color_description"
        case isShareSeller = "is_share_seller"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        landmark = container.decodeStringLeniently(forKey: .landmark) ?? ""
        latitude = container.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = container.decodeStringLeniently(forKey: .longitude) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        whatsappNo = container.decodeStringLeniently(forKey: .whatsappNo) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        city = container.decodeStringLeniently(forKey: .city) ?? ""
        state = container.decodeStringLeniently(forKey: .state) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        beat = container.decodeStringLeniently(forKey: .beat) ?? ""
        manualAddress = container.decodeStringLeniently(forKey: .manualAddress) ?? ""
        colorId = container.decodeIntLeniently(forKey: .colorId)
        colorDescription = container.decodeStringLeniently(forKey: .colorDescription)
        isShareSeller = container.decodeBoolLeniently(forKey: .isShareSeller) ?? false
    }

    var canUpdateColor: Bool {
        isShareSeller
    }

    var displayShopName: String {
        shopName.isEmptyString ? "Shop name not available" : shopName
    }

    var displayOwnerName: String {
        name.isEmptyString ? "Owner name not available" : name
    }

    var flagColor: Color? {
        guard let colorId else { return nil }
        return SellerProfileColorPalette.color(for: colorId)
    }
}

struct SellerProfileFinancialStats: Decodable {
    var totalAmount: String
    var pendingAmount: String
    var paidAmount: String

    enum CodingKeys: String, CodingKey {
        case totalAmount = "total_amount"
        case pendingAmount = "pending_amount"
        case paidAmount = "paid_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalAmount = container.decodeStringLeniently(forKey: .totalAmount) ?? "0"
        pendingAmount = container.decodeStringLeniently(forKey: .pendingAmount) ?? "0"
        paidAmount = container.decodeStringLeniently(forKey: .paidAmount) ?? "0"
    }
}

struct SellerProfileOrderDistribution: Decodable {
    var pending: Int
    var toDeliver: Int
    var pickup: Int
    var delivered: Int
    var cancel: Int
    var returnCount: Int
    var assign: Int

    enum CodingKeys: String, CodingKey {
        case pending = "Pending"
        case toDeliver = "To Deliver"
        case pickup = "Pickup"
        case delivered = "Delivered"
        case cancel = "Cancel"
        case returnCount = "Return"
        case assign = "Assign"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pending = container.decodeIntLeniently(forKey: .pending) ?? 0
        toDeliver = container.decodeIntLeniently(forKey: .toDeliver) ?? 0
        pickup = container.decodeIntLeniently(forKey: .pickup) ?? 0
        delivered = container.decodeIntLeniently(forKey: .delivered) ?? 0
        cancel = container.decodeIntLeniently(forKey: .cancel) ?? 0
        returnCount = container.decodeIntLeniently(forKey: .returnCount) ?? 0
        assign = container.decodeIntLeniently(forKey: .assign) ?? 0
    }
}

struct SellerProfilePaymentModeCounts: Decodable {
    var cash: Int
    var cheque: Int
    var upi: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cash = container.decodeIntLeniently(forKey: .cash) ?? 0
        cheque = container.decodeIntLeniently(forKey: .cheque) ?? 0
        upi = container.decodeIntLeniently(forKey: .upi) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case cash, cheque, upi
    }
}

struct SellerProfilePaymentModeAmounts: Decodable {
    var cash: String
    var cheque: String
    var upi: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cash = container.decodeStringLeniently(forKey: .cash) ?? "0"
        cheque = container.decodeStringLeniently(forKey: .cheque) ?? "0"
        upi = container.decodeStringLeniently(forKey: .upi) ?? "0"
    }

    enum CodingKeys: String, CodingKey {
        case cash, cheque, upi
    }
}

struct SellerProfileTopCategory: Identifiable, Decodable {
    var id: String { categoryName }
    var categoryName: String
    var totalQuantity: String
    var totalAmount: String

    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case totalQuantity = "total_quantity"
        case totalAmount = "total_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryName = container.decodeStringLeniently(forKey: .categoryName) ?? ""
        totalQuantity = container.decodeStringLeniently(forKey: .totalQuantity) ?? "0"
        totalAmount = container.decodeStringLeniently(forKey: .totalAmount) ?? "0"
    }
}

struct SellerProfileTopProduct: Identifiable, Decodable {
    var id: String { productName }
    var productName: String
    var totalQuantity: String
    var totalAmount: String

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case totalQuantity = "total_quantity"
        case totalAmount = "total_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        totalQuantity = container.decodeStringLeniently(forKey: .totalQuantity) ?? "0"
        totalAmount = container.decodeStringLeniently(forKey: .totalAmount) ?? "0"
    }
}

extension String {
    var parsedAmount: Double {
        Double(self.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}

enum SellerContactActionError: LocalizedError {
    case phoneUnavailable
    case whatsAppUnavailable
    case emailUnavailable
    case locationUnavailable
    case appUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .phoneUnavailable:
            return "Phone number is not available."
        case .whatsAppUnavailable:
            return "WhatsApp number is not available."
        case .emailUnavailable:
            return "Email address is not available."
        case .locationUnavailable:
            return "Location is not available."
        case .appUnavailable(let message):
            return message
        }
    }
}

struct SellerProfileLegendItem: Identifiable {
    var id: String { title }
    var title: String
    var count: Int
    var color: Color

    static var emptyList: [SellerProfileLegendItem] {
        [
            .init(title: "Delivered", count: 0, color: DashboardTheme.successGreen),
            .init(title: "Pending", count: 0, color: DashboardTheme.warningYellow),
            .init(title: "To Deliver", count: 0, color: DashboardTheme.infoBlue),
            .init(title: "Assigned", count: 0, color: DashboardTheme.primaryBlue),
            .init(title: "Pickup", count: 0, color: DashboardTheme.pickupOrange),
            .init(title: "Cancelled", count: 0, color: DashboardTheme.dangerRed),
            .init(title: "Returned", count: 0, color: DashboardTheme.neutralMedium)
        ]
    }
}

enum SellerProfilePaymentChartMode: String, CaseIterable, Identifiable {
    case count
    case amount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .count: return "By Count"
        case .amount: return "By Amount"
        }
    }
}

struct SellerProfilePaymentLegendRow: Identifiable {
    var id: String { title }
    var title: String
    var primaryValue: String
    var percentage: String
    var color: Color
}

struct SellerProfileColorItem: Identifiable, Decodable {
    var id: Int
    var name: String
    var description: String

    init(id: Int, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        description = container.decodeStringLeniently(forKey: .description) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
    }

    var displayColor: Color {
        SellerProfileColorPalette.color(for: id)
    }

    static var fallbackItems: [SellerProfileColorItem] {
        [
            .init(id: 1, name: "Green", description: "Green color"),
            .init(id: 4, name: "Orange", description: "Orange color"),
            .init(id: 3, name: "Red", description: "Red color")
        ]
    }
}

enum SellerProfileColorPalette {
    static func color(for colorId: Int) -> Color {
        switch colorId {
        case 1: return DashboardTheme.successGreen
        case 3: return DashboardTheme.dangerRed
        case 4: return DashboardTheme.pickupOrange
        default: return DashboardTheme.neutralMedium
        }
    }
}

struct SellerProfileColorListResponse: Decodable {
    var status: Bool
    var message: String
    var colors: [SellerProfileColorItem]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        colors = (try? container.decode([SellerProfileColorItem].self, forKey: .data)) ?? []
    }
}

struct SellerProfileActionResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
    }
}

extension SellerProfileDatePreset {
    static var ordersTabPresets: [SellerProfileDatePreset] {
        [.yesterday, .thisWeek, .lastWeek, .thisMonth]
    }

    static var paymentsTabPresets: [SellerProfileDatePreset] {
        [.thisMonth, .lastMonth, .thisYear]
    }
}

enum SellerProfileTransactionStatusFilter: String, CaseIterable, Identifiable {
    case pending
    case remaining
    case complete

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var apiKey: String {
        switch self {
        case .pending: return "0"
        case .remaining: return "1"
        case .complete: return "2"
        }
    }
}

enum SellerProfileOrderStatusColor {
    static func color(for statusId: String) -> Color {
        switch statusId {
        case "0": return DashboardTheme.warningYellow
        case "1": return DashboardTheme.infoBlue
        case "2": return DashboardTheme.pickupOrange
        case "3": return DashboardTheme.successGreen
        case "4": return DashboardTheme.dangerRed
        case "5": return DashboardTheme.secondaryPurple
        case "6": return DashboardTheme.primaryBlue
        default: return DashboardTheme.neutralMedium
        }
    }
}

enum SellerProfileTransactionStatusStyle {
    static func color(for status: String) -> Color {
        switch status.lowercased() {
        case "complete": return DashboardTheme.successGreen
        case "remaining": return DashboardTheme.warningYellow
        case "pending": return DashboardTheme.dangerRed
        default: return DashboardTheme.neutralMedium
        }
    }

    static func icon(for status: String) -> String {
        switch status.lowercased() {
        case "complete": return "checkmark.circle.fill"
        case "remaining": return "exclamationmark.triangle.fill"
        case "pending": return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
}

extension SellerProfileDateFormat {
    static func displayDate(_ apiDate: String, format: String = "dd MMM yyyy") -> String {
        guard let date = apiFormatter.date(from: apiDate) else { return apiDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func displayDateShort(_ apiDate: String) -> String {
        displayDate(apiDate, format: "dd MMM, yyyy")
    }
}

struct SellerProfileOrderListResponse: Decodable {
    var status: Bool
    var message: String
    var orders: [SellerProfileOrderItem]
    var statusMap: [SellerProfileOrderStatusOption]
    var currentPage: Int
    var lastPage: Int

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""

        if let dataContainer = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            let pagination = try? dataContainer.nestedContainer(keyedBy: PaginationKeys.self, forKey: .orders)
            orders = (try? pagination?.decode([SellerProfileOrderItem].self, forKey: .data)) ?? []
            currentPage = pagination?.decodeIntLeniently(forKey: .currentPage) ?? 1
            lastPage = pagination?.decodeIntLeniently(forKey: .lastPage) ?? 1
            statusMap = (try? dataContainer.decode([SellerProfileOrderStatusOption].self, forKey: .statusMap)) ?? []
        } else {
            orders = []
            statusMap = []
            currentPage = 1
            lastPage = 1
        }
    }

    var canLoadMore: Bool { currentPage < lastPage }

    private enum DataKeys: String, CodingKey {
        case orders
        case statusMap = "status_map"
    }

    private enum PaginationKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
        case lastPage = "last_page"
    }
}

struct SellerProfileOrderItem: Identifiable, Decodable {
    var id: String { orderId }
    var orderId: String
    var orderDate: String
    var status: String
    var statusText: String
    var totalPrice: String

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case orderDate = "order_date"
        case statusText = "status_text"
        case totalPrice = "total_price"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusText = container.decodeStringLeniently(forKey: .statusText) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
    }

    var amount: Double { totalPrice.parsedAmount }
    var detailOrderId: String {
        orderId.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SellerProfileOrderStatusOption: Identifiable, Decodable {
    var id: String { String(key) }
    var key: Int
    var label: String
}

struct SellerProfileTransactionListResponse: Decodable {
    var status: Bool
    var message: String
    var transactions: [SellerProfileTransactionItem]
    var currentPage: Int
    var lastPage: Int

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""

        if let dataContainer = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            transactions = (try? dataContainer.decode([SellerProfileTransactionItem].self, forKey: .transactions)) ?? []
            currentPage = dataContainer.decodeIntLeniently(forKey: .currentPage) ?? 1
            lastPage = dataContainer.decodeIntLeniently(forKey: .lastPage) ?? 1
        } else {
            transactions = []
            currentPage = 1
            lastPage = 1
        }
    }

    var canLoadMore: Bool { currentPage < lastPage }

    private enum DataKeys: String, CodingKey {
        case transactions
        case currentPage = "current_page"
        case lastPage = "last_page"
    }
}

struct SellerProfileTransactionItem: Identifiable, Decodable {
    var id: String
    var amount: String
    var remainingAmount: String
    var paymentMode: String
    var transactionStatus: String
    var date: String
    var history: [SellerProfileTransactionHistoryItem]

    enum CodingKeys: String, CodingKey {
        case id, amount, date
        case remainingAmount = "remaining_amount"
        case paymentMode = "payment_mode"
        case transactionStatus = "transaction_status"
        case history = "transaction_history"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeStringLeniently(forKey: .id) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        remainingAmount = container.decodeStringLeniently(forKey: .remainingAmount) ?? "0"
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        transactionStatus = container.decodeStringLeniently(forKey: .transactionStatus) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        history = (try? container.decode([SellerProfileTransactionHistoryItem].self, forKey: .history)) ?? []
    }

    var totalAmount: Double { amount.parsedAmount }
    var pendingAmount: Double { remainingAmount.parsedAmount }
    var isFullySettled: Bool { pendingAmount <= 0 }
}

struct SellerProfileTransactionHistoryItem: Identifiable, Decodable {
    var id: Int
    var amount: String
    var date: String
    var paymentMode: String

    enum CodingKeys: String, CodingKey {
        case id, amount, date
        case paymentMode = "payment_mode"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
    }

    var settledAmount: Double { amount.parsedAmount }
}
