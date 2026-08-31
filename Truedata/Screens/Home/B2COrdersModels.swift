//
//  B2COrdersModels.swift
//  Truedata
//

import Foundation
import SwiftUI

struct B2COrderListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [B2CCustomerOrderItem]
    var pagination: B2CPagination?

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode([B2CCustomerOrderItem].self, forKey: .data)) ?? []
        pagination = try? container.decode(B2CPagination.self, forKey: .pagination)
    }
}

struct B2CCustomerOrderItem: Decodable, Identifiable, Hashable {
    var orderId: Int
    var orderNo: String
    var customerName: String
    var customerMobile: String
    var customerAddress: String
    var totalPrice: String
    var totalAmount: Double
    var paymentType: String
    var paymentStatus: String
    var paymentLabel: String
    var invoiceLink: String
    var orderDate: String
    var displayDate: String
    var itemsCount: Int
    var status: B2COrderStatusInfo?

    var id: Int { orderId }

    func hash(into hasher: inout Hasher) {
        hasher.combine(orderId)
    }

    static func == (lhs: B2CCustomerOrderItem, rhs: B2CCustomerOrderItem) -> Bool {
        lhs.orderId == rhs.orderId
    }

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case orderNo = "order_no"
        case customerName = "customer_name"
        case customerMobile = "customer_mobile"
        case customerAddress = "customer_address"
        case totalPrice = "total_price"
        case totalAmount = "total_amount"
        case paymentType = "payment_type"
        case paymentStatus = "payment_status"
        case paymentLabel = "payment_label"
        case invoiceLink = "invoice_link"
        case orderDate = "order_date"
        case displayDate = "date"
        case itemsCount = "items_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        customerName = container.decodeStringLeniently(forKey: .customerName) ?? ""
        customerMobile = container.decodeStringLeniently(forKey: .customerMobile) ?? ""
        customerAddress = container.decodeStringLeniently(forKey: .customerAddress) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? ""
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? (Double(totalPrice) ?? 0)
        paymentType = container.decodeStringLeniently(forKey: .paymentType) ?? ""
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        paymentLabel = container.decodeStringLeniently(forKey: .paymentLabel) ?? ""
        invoiceLink = container.decodeStringLeniently(forKey: .invoiceLink) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        displayDate = container.decodeStringLeniently(forKey: .displayDate) ?? orderDate
        itemsCount = container.decodeIntLeniently(forKey: .itemsCount) ?? 0
        status = try? container.decode(B2COrderStatusInfo.self, forKey: .status)
    }

    var resolvedStatusLabel: String {
        if let label = status?.label, !label.isEmptyString {
            return label
        }
        if !paymentStatus.isEmptyString {
            return paymentStatus.capitalized
        }
        return "Pending"
    }

    var resolvedStatusColor: Color {
        if let hex = status?.color, !hex.isEmptyString {
            return Color(hex: hex)
        }
        switch resolvedStatusLabel.lowercased() {
        case "pending": return DashboardTheme.warningYellow
        case "confirmed", "processing": return DashboardTheme.infoBlue
        case "dispatched", "running", "on the way": return DashboardTheme.pickupOrange
        case "delivered", "completed": return DashboardTheme.successGreen
        case "cancelled", "failed": return DashboardTheme.dangerRed
        default: return DashboardTheme.primaryBlue
        }
    }

    var isPaid: Bool {
        paymentStatus.lowercased() == "paid"
    }
}

struct B2COrderStatusInfo: Decodable, Hashable {
    var code: Int
    var label: String
    var color: String

    enum CodingKeys: String, CodingKey {
        case code, label, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = container.decodeIntLeniently(forKey: .code) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? ""
        color = container.decodeStringLeniently(forKey: .color) ?? ""
    }
}

struct B2CPagination: Decodable {
    var currentPage: Int
    var lastPage: Int
    var perPage: Int
    var total: Int
    var hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case total
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 10
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        hasMore = container.decodeBoolLeniently(forKey: .hasMore) ?? (currentPage < lastPage)
    }
}

enum B2CDateRangeFilter: String, CaseIterable, Identifiable, Codable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"

    var id: String { rawValue }
}

enum B2CPaymentModeFilter: String, CaseIterable, Identifiable, Codable {
    case all = "All Payment Modes"
    case cod = "Cash on Delivery (COD)"
    case online = "Online / Prepaid"

    var id: String { rawValue }
}

enum B2COrderStatusFilter: String, CaseIterable, Identifiable, Codable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case dispatched = "Dispatched"
    case delivered = "Delivered"
    case cancelled = "Cancelled"
    case all = "All Orders"

    var id: String { rawValue }

    var statusCode: String {
        switch self {
        case .all: return "all"
        case .pending: return "0"
        case .confirmed: return "1"
        case .dispatched: return "2"
        case .delivered: return "3"
        case .cancelled: return "4"
        }
    }
}

enum B2COrderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case confirmed = "Confirmed"
    case dispatched = "Dispatched"
    case delivered = "Delivered"
    case cancelled = "Cancelled"

    var id: String { rawValue }

    var statusCode: String {
        switch self {
        case .all: return "all"
        case .pending: return "0"
        case .confirmed: return "1"
        case .dispatched: return "2"
        case .delivered: return "3"
        case .cancelled: return "4"
        }
    }
}

extension Date {
    var isTodayDate: Bool { Calendar.current.isDateInToday(self) }
    var isYesterdayDate: Bool { Calendar.current.isDateInYesterday(self) }
    var isThisWeekDate: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    var isLastWeekDate: Bool {
        guard let prevWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return false }
        return Calendar.current.isDate(self, equalTo: prevWeek, toGranularity: .weekOfYear)
    }
    var isThisMonthDate: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    var isLastMonthDate: Bool {
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return false }
        return Calendar.current.isDate(self, equalTo: prevMonth, toGranularity: .month)
    }
    var isThisYearDate: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
}

extension B2CCustomerOrderItem {
    var parsedDate: Date? {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "dd MMM yyyy, hh:mm a",
            "dd MMM yyyy",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            df.dateFormat = fmt
            if let d = df.date(from: orderDate) ?? df.date(from: displayDate) {
                return d
            }
        }
        return nil
    }

    func matches(dateRange: B2CDateRangeFilter) -> Bool {
        guard let d = parsedDate else { return true }
        switch dateRange {
        case .today: return d.isTodayDate
        case .yesterday: return d.isYesterdayDate
        case .thisWeek: return d.isThisWeekDate
        case .lastWeek: return d.isLastWeekDate
        case .thisMonth: return d.isThisMonthDate
        case .lastMonth: return d.isLastMonthDate
        case .thisYear: return d.isThisYearDate
        }
    }

    func matches(paymentMode: B2CPaymentModeFilter) -> Bool {
        switch paymentMode {
        case .all:
            return true
        case .cod:
            let type = (paymentType + " " + paymentLabel).lowercased()
            return type.contains("cod") || type.contains("cash") || type.contains("delivery")
        case .online:
            let type = (paymentType + " " + paymentLabel).lowercased()
            return type.contains("online") || type.contains("upi") || type.contains("prepaid") || type.contains("paid")
        }
    }

    func matches(statusFilter: B2COrderStatusFilter) -> Bool {
        switch statusFilter {
        case .all:
            return true
        case .pending:
            return status?.code == 0 || resolvedStatusLabel.lowercased() == "pending"
        case .confirmed:
            return status?.code == 1 || resolvedStatusLabel.lowercased() == "confirmed"
        case .dispatched:
            return status?.code == 2 || resolvedStatusLabel.lowercased().contains("dispatch") || resolvedStatusLabel.lowercased().contains("running")
        case .delivered:
            return status?.code == 3 || resolvedStatusLabel.lowercased() == "delivered"
        case .cancelled:
            return status?.code == 4 || resolvedStatusLabel.lowercased() == "cancelled"
        }
    }
}

// MARK: - B2C Order Detail Models

struct B2COrderDetailResponse: Decodable {
    var status: Bool
    var message: String
    var data: B2COrderDetailData?

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
        data = try? container.decode(B2COrderDetailData.self, forKey: .data)
    }
}

struct B2COrderDetailData: Decodable, Identifiable {
    var id: Int
    var orderNo: String
    var date: String
    var status: String
    var statusCode: Int
    var paymentType: String
    var paymentStatus: String
    var paymentLabel: String
    var totalMrp: Double
    var itemsTotal: Double
    var totalSave: Double
    var deliveryCharge: Double
    var handlingCharge: Double
    var packingCharge: Double
    var couponCode: String?
    var couponDiscount: Double
    var totalAmount: Double
    var notes: String?
    var customerName: String
    var customerMobile: String
    var customerAddress: String
    var invoiceLink: String
    var canConfirm: Bool
    var canDispatch: Bool
    var canDeliver: Bool
    var canCancel: Bool
    var items: [B2COrderDetailItem]

    enum CodingKeys: String, CodingKey {
        case id, date, status, notes, items
        case orderNo = "order_no"
        case statusCode = "status_code"
        case paymentType = "payment_type"
        case paymentStatus = "payment_status"
        case paymentLabel = "payment_label"
        case totalMrp = "total_mrp"
        case itemsTotal = "items_total"
        case totalSave = "total_save"
        case deliveryCharge = "delivery_charge"
        case handlingCharge = "handling_charge"
        case packingCharge = "packing_charge"
        case couponCode = "coupon_code"
        case couponDiscount = "coupon_discount"
        case totalAmount = "total_amount"
        case customerName = "customer_name"
        case customerMobile = "customer_mobile"
        case customerAddress = "customer_address"
        case invoiceLink = "invoice_link"
        case canConfirm = "can_confirm"
        case canDispatch = "can_dispatch"
        case canDeliver = "can_deliver"
        case canCancel = "can_cancel"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusCode = container.decodeIntLeniently(forKey: .statusCode) ?? 0
        paymentType = container.decodeStringLeniently(forKey: .paymentType) ?? ""
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        paymentLabel = container.decodeStringLeniently(forKey: .paymentLabel) ?? ""
        totalMrp = container.decodeDoubleLeniently(forKey: .totalMrp) ?? 0
        itemsTotal = container.decodeDoubleLeniently(forKey: .itemsTotal) ?? 0
        totalSave = container.decodeDoubleLeniently(forKey: .totalSave) ?? 0
        deliveryCharge = container.decodeDoubleLeniently(forKey: .deliveryCharge) ?? 0
        handlingCharge = container.decodeDoubleLeniently(forKey: .handlingCharge) ?? 0
        packingCharge = container.decodeDoubleLeniently(forKey: .packingCharge) ?? 0
        couponCode = container.decodeStringLeniently(forKey: .couponCode)
        couponDiscount = container.decodeDoubleLeniently(forKey: .couponDiscount) ?? 0
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
        notes = container.decodeStringLeniently(forKey: .notes)
        customerName = container.decodeStringLeniently(forKey: .customerName) ?? ""
        customerMobile = container.decodeStringLeniently(forKey: .customerMobile) ?? ""
        customerAddress = container.decodeStringLeniently(forKey: .customerAddress) ?? ""
        invoiceLink = container.decodeStringLeniently(forKey: .invoiceLink) ?? ""
        canConfirm = container.decodeBoolLeniently(forKey: .canConfirm) ?? false
        canDispatch = container.decodeBoolLeniently(forKey: .canDispatch) ?? false
        canDeliver = container.decodeBoolLeniently(forKey: .canDeliver) ?? false
        canCancel = container.decodeBoolLeniently(forKey: .canCancel) ?? false
        items = (try? container.decode([B2COrderDetailItem].self, forKey: .items)) ?? []
    }

    var isPaid: Bool {
        paymentStatus.lowercased() == "paid"
    }

    var statusColor: Color {
        switch statusCode {
        case 0: return DashboardTheme.warningYellow
        case 1: return DashboardTheme.infoBlue
        case 2: return DashboardTheme.pickupOrange
        case 3: return DashboardTheme.successGreen
        case 4: return DashboardTheme.dangerRed
        default: return DashboardTheme.primaryBlue
        }
    }
}

struct B2COrderDetailItem: Decodable, Identifiable {
    var productId: Int
    var productName: String
    var productImage: String
    var variantId: Int
    var weight: String
    var mrp: Double
    var customerPrice: Double
    var saveAmount: Double
    var discountPercent: Double
    var qty: Int
    var price: Double

    var id: String { "\(productId)_\(variantId)_\(qty)" }

    enum CodingKeys: String, CodingKey {
        case weight, qty, price, mrp
        case productId = "product_id"
        case productName = "product_name"
        case productImage = "product_image"
        case variantId = "variant_id"
        case customerPrice = "customer_price"
        case saveAmount = "save_amount"
        case discountPercent = "discount_percent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productId = container.decodeIntLeniently(forKey: .productId) ?? 0
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        productImage = container.decodeStringLeniently(forKey: .productImage) ?? ""
        variantId = container.decodeIntLeniently(forKey: .variantId) ?? 0
        weight = container.decodeStringLeniently(forKey: .weight) ?? ""
        mrp = container.decodeDoubleLeniently(forKey: .mrp) ?? 0
        customerPrice = container.decodeDoubleLeniently(forKey: .customerPrice) ?? 0
        saveAmount = container.decodeDoubleLeniently(forKey: .saveAmount) ?? 0
        discountPercent = container.decodeDoubleLeniently(forKey: .discountPercent) ?? 0
        qty = container.decodeIntLeniently(forKey: .qty) ?? 0
        price = container.decodeDoubleLeniently(forKey: .price) ?? 0
    }
}

// MARK: - B2C Order Status Update Models

struct B2COrderStatusUpdateResponse: Decodable {
    var status: Bool
    var message: String
    var data: B2COrderStatusUpdateData?

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
        data = try? container.decode(B2COrderStatusUpdateData.self, forKey: .data)
    }
}

struct B2COrderStatusUpdateData: Decodable {
    var id: Int
    var orderNo: String
    var statusCode: Int
    var statusLabel: String
    var date: String

    enum CodingKeys: String, CodingKey {
        case id, date
        case orderNo = "order_no"
        case statusCode = "status_code"
        case statusLabel = "status_label"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        statusCode = container.decodeIntLeniently(forKey: .statusCode) ?? 0
        statusLabel = container.decodeStringLeniently(forKey: .statusLabel) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
    }
}


