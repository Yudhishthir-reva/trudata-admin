//
//  RetailerAppPaymentModels.swift
//  Truedata
//

import Foundation

enum RetailerPaymentStatus: String, CaseIterable, Identifiable {
    case pending = "0"
    case approved = "1"
    case rejected = "2"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

enum RetailerPaymentDatePreset: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last7Days = "Last 7 days"
    case thisMonth = "This month"
    case allTime = "All time"
    case custom = "Custom"

    var id: String { rawValue }

    func dateRange() -> (start: String, end: String) {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch self {
        case .today:
            let str = formatter.string(from: now)
            return (str, str)
        case .yesterday:
            let yDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let str = formatter.string(from: yDate)
            return (str, str)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            return (formatter.string(from: start), formatter.string(from: now))
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: comps) ?? now
            return (formatter.string(from: startOfMonth), formatter.string(from: now))
        case .allTime:
            return ("", "")
        case .custom:
            return ("", "")
        }
    }
}

struct RetailerPaymentFilters: Equatable {
    var datePreset: RetailerPaymentDatePreset = .today
    var startDate: String = ""
    var endDate: String = ""
    var sellerId: String? = nil
    var sellerName: String? = nil

    var isDefault: Bool {
        datePreset == .today && (sellerId == nil || sellerId?.isEmpty == true)
    }

    var isFiltered: Bool {
        !isDefault
    }
}

struct RetailerPaymentRequestListResponse: Decodable {
    var status: Bool
    var message: String
    var data: RetailerPaymentRequestData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? true

        if let msg = container.decodeStringLeniently(forKey: .message) {
            message = msg
        } else if let msgs = try? container.decode([String].self, forKey: .message) {
            message = msgs.first ?? ""
        } else {
            message = ""
        }

        if let dataObj = try? container.decode(RetailerPaymentRequestData.self, forKey: .data) {
            data = dataObj
        } else if let list = try? container.decode([RetailerPaymentItem].self, forKey: .data) {
            data = RetailerPaymentRequestData(payments: list, currentPage: 1, lastPage: 1, total: list.count)
        } else {
            data = RetailerPaymentRequestData()
        }
    }
}

struct RetailerPaymentRequestData: Decodable {
    var payments: [RetailerPaymentItem]
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var pendingCount: Int
    var approvedCount: Int
    var rejectedCount: Int

    enum CodingKeys: String, CodingKey {
        case payments, data, list, items
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case pendingCount = "pending_count"
        case approvedCount = "approved_count"
        case rejectedCount = "rejected_count"
        case counts
    }

    init(
        payments: [RetailerPaymentItem] = [],
        currentPage: Int = 1,
        lastPage: Int = 1,
        total: Int = 0,
        pendingCount: Int = 0,
        approvedCount: Int = 0,
        rejectedCount: Int = 0
    ) {
        self.payments = payments
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.pendingCount = pendingCount
        self.approvedCount = approvedCount
        self.rejectedCount = rejectedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let list = try? container.decode([RetailerPaymentItem].self, forKey: .payments) {
            payments = list
        } else if let list = try? container.decode([RetailerPaymentItem].self, forKey: .data) {
            payments = list
        } else if let list = try? container.decode([RetailerPaymentItem].self, forKey: .list) {
            payments = list
        } else if let list = try? container.decode([RetailerPaymentItem].self, forKey: .items) {
            payments = list
        } else {
            payments = []
        }

        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        total = container.decodeIntLeniently(forKey: .total) ?? payments.count

        pendingCount = container.decodeIntLeniently(forKey: .pendingCount) ?? 0
        approvedCount = container.decodeIntLeniently(forKey: .approvedCount) ?? 0
        rejectedCount = container.decodeIntLeniently(forKey: .rejectedCount) ?? 0
    }
}

struct RetailerPaymentSellerInfo: Decodable, Hashable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sellerName = "seller_name"
        case customerName = "customer_name"
        case userName = "user_name"
        case shopName = "shop_name"
        case storeName = "store_name"
        case mobile
        case phone
        case contactNumber = "contact_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name)
            ?? container.decodeStringLeniently(forKey: .sellerName)
            ?? container.decodeStringLeniently(forKey: .customerName)
            ?? container.decodeStringLeniently(forKey: .userName)
            ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName)
            ?? container.decodeStringLeniently(forKey: .storeName)
            ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile)
            ?? container.decodeStringLeniently(forKey: .phone)
            ?? container.decodeStringLeniently(forKey: .contactNumber)
            ?? ""
    }
}

struct RetailerPaymentItem: Decodable, Identifiable, Hashable {
    var id: Int
    var amount: Double
    var status: String
    var createdAt: String
    var shopName: String
    var sellerName: String
    var mobile: String
    var refUtr: String
    var paymentMode: String
    var remark: String
    var message: String
    var sellerId: Int

    enum CodingKeys: String, CodingKey {
        case id, amount, status, remark, message, seller
        case createdAt = "created_at"
        case shopName = "shop_name"
        case storeName = "store_name"
        case sellerName = "seller_name"
        case customerName = "customer_name"
        case userName = "user_name"
        case name
        case mobile
        case phone
        case contactNumber = "contact_number"
        case refUtr = "ref_utr"
        case utr
        case refNo = "ref_no"
        case transactionId = "transaction_id"
        case paymentMode = "payment_mode"
        case mode
        case adminRemark = "admin_remark"
        case adminReason = "admin_reason"
        case reason
        case paymentMessage = "payment_message"
        case paymentDescriptionField = "payment_description"
        case description
        case sellerId = "seller_id"
    }

    init(
        id: Int,
        amount: Double,
        status: String,
        createdAt: String,
        shopName: String,
        sellerName: String,
        mobile: String,
        refUtr: String,
        paymentMode: String,
        remark: String,
        message: String = "",
        sellerId: Int = 0
    ) {
        self.id = id
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
        self.shopName = shopName
        self.sellerName = sellerName
        self.mobile = mobile
        self.refUtr = refUtr
        self.paymentMode = paymentMode
        self.remark = remark
        self.message = message
        self.sellerId = sellerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = container.decodeDoubleLeniently(forKey: .amount) ?? 0.0
        status = container.decodeStringLeniently(forKey: .status) ?? "0"
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""

        let sellerObj = try? container.decode(RetailerPaymentSellerInfo.self, forKey: .seller)

        let decodedShop = container.decodeStringLeniently(forKey: .shopName)
            ?? container.decodeStringLeniently(forKey: .storeName)
            ?? ""
        shopName = !(sellerObj?.shopName.isEmpty ?? true) ? sellerObj!.shopName : decodedShop

        let decodedSellerName = container.decodeStringLeniently(forKey: .sellerName)
            ?? container.decodeStringLeniently(forKey: .customerName)
            ?? container.decodeStringLeniently(forKey: .userName)
            ?? container.decodeStringLeniently(forKey: .name)
            ?? ""
        sellerName = !(sellerObj?.name.isEmpty ?? true) ? sellerObj!.name : decodedSellerName

        let decodedMobile = container.decodeStringLeniently(forKey: .mobile)
            ?? container.decodeStringLeniently(forKey: .phone)
            ?? container.decodeStringLeniently(forKey: .contactNumber)
            ?? ""
        mobile = !(sellerObj?.mobile.isEmpty ?? true) ? sellerObj!.mobile : decodedMobile

        let decodedSellerId = container.decodeIntLeniently(forKey: .sellerId) ?? 0
        sellerId = (sellerObj?.id ?? 0) > 0 ? (sellerObj?.id ?? 0) : decodedSellerId

        refUtr = container.decodeStringLeniently(forKey: .refUtr)
            ?? container.decodeStringLeniently(forKey: .utr)
            ?? container.decodeStringLeniently(forKey: .refNo)
            ?? container.decodeStringLeniently(forKey: .transactionId)
            ?? ""

        paymentMode = container.decodeStringLeniently(forKey: .paymentMode)
            ?? container.decodeStringLeniently(forKey: .mode)
            ?? "UPI"

        remark = container.decodeStringLeniently(forKey: .adminRemark)
            ?? container.decodeStringLeniently(forKey: .remark)
            ?? container.decodeStringLeniently(forKey: .adminReason)
            ?? container.decodeStringLeniently(forKey: .reason)
            ?? ""

        message = container.decodeStringLeniently(forKey: .message)
            ?? container.decodeStringLeniently(forKey: .paymentMessage)
            ?? container.decodeStringLeniently(forKey: .paymentDescriptionField)
            ?? container.decodeStringLeniently(forKey: .description)
            ?? ""
    }

    var statusEnum: RetailerPaymentStatus {
        switch status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1", "approved", "approve":
            return .approved
        case "2", "rejected", "reject":
            return .rejected
        default:
            return .pending
        }
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }

    var formattedDateTime: String {
        guard !createdAt.isEmpty else { return "-" }
        let inputFormatters = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ]

        var parsedDate: Date?
        for format in inputFormatters {
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: createdAt) {
                parsedDate = date
                break
            }
        }

        guard let date = parsedDate else { return createdAt }

        let outDf = DateFormatter()
        outDf.dateFormat = "d MMM yyyy, h:mm a"
        outDf.locale = Locale(identifier: "en_US_POSIX")
        return outDf.string(from: date)
    }

    var personSubtitle: String {
        if !sellerName.isEmpty && !mobile.isEmpty {
            return "\(sellerName) · \(mobile)"
        } else if !sellerName.isEmpty {
            return sellerName
        } else if !mobile.isEmpty {
            return mobile
        } else {
            return "-"
        }
    }

    var paymentDescription: String {
        if !message.isEmpty {
            return message
        }
        let name = sellerName.isEmpty ? "Retailer" : sellerName
        var details: [String] = []
        if !refUtr.isEmpty {
            details.append("Ref/UTR: \(refUtr)")
        }
        if !paymentMode.isEmpty {
            details.append("Mode: \(paymentMode)")
        }
        let detailsStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
        return "Payment from \(name)\(detailsStr)"
    }
}
