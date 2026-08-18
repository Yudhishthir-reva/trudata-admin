//
//  PaymentInsightsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum PaymentInsightsViewMode: String, CaseIterable {
    case report = "Report"
    case settlements = "Settlements"
    case bills = "Bills"
}

enum PaymentInsightsFilterCategory: String, CaseIterable {
    case dateRange = "Date Range"
    case paymentMode = "Payment Mode"
    case paymentStatus = "Payment Status"
    case staff = "Staff"
    case seller = "Seller"
}

struct PaymentInsightsFilterOption: Identifiable, Hashable {
    let id: String
    let title: String
}

enum PaymentInsightsPaymentMode {
    static let options: [PaymentInsightsFilterOption] = [
        .init(id: "", title: "All"),
        .init(id: "1", title: "Cash"),
        .init(id: "2", title: "Cheque"),
        .init(id: "3", title: "UPI"),
        .init(id: "0", title: "N/A")
    ]

    static func title(for id: String) -> String {
        options.first(where: { $0.id == id })?.title ?? "N/A"
    }
}

enum PaymentInsightsPaymentStatus {
    static let options: [PaymentInsightsFilterOption] = [
        .init(id: "", title: "All"),
        .init(id: "0", title: "Pending"),
        .init(id: "1", title: "Remaining"),
        .init(id: "2", title: "Complete")
    ]

    static func title(for id: String) -> String {
        options.first(where: { $0.id == id })?.title ?? "Unknown"
    }

    static func color(for id: String) -> Color {
        switch id {
        case "0": return DashboardTheme.warningYellow
        case "1": return DashboardTheme.infoBlue
        case "2": return DashboardTheme.successGreen
        default: return DashboardTheme.neutralMedium
        }
    }
}

struct PaymentInsightsAppliedFilters {
    var startDate: String
    var endDate: String
    var datePreset: OrderInsightsDatePreset
    var paymentMode: String
    var paymentStatus: String
    var staffId: String
    var sellerId: String
}

struct PaymentHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var summary: PaymentInsightsSummary?
    var page: PaymentHistoryPage

    enum CodingKeys: String, CodingKey {
        case status, message, summary, Summary, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        page = (try? container.decode(PaymentHistoryPage.self, forKey: .data)) ?? PaymentHistoryPage()
        summary = PaymentInsightsSummary.parse(from: container, page: page)
    }
}

struct PaymentHistoryPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var transactions: [PaymentTransactionItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case inner = "data"
    }

    init(currentPage: Int = 0, lastPage: Int = 0, total: Int = 0, transactions: [PaymentTransactionItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.transactions = transactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0

        if let inner = try? container.decode(PaymentHistoryInnerPage.self, forKey: .inner) {
            currentPage = inner.currentPage > 0 ? inner.currentPage : currentPage
            lastPage = inner.lastPage > 0 ? inner.lastPage : lastPage
            total = inner.total > 0 ? inner.total : total
            transactions = inner.transactions
        } else if let directList = try? container.decode([PaymentTransactionItem].self, forKey: .inner) {
            transactions = directList
        } else {
            transactions = []
        }
    }
}

private struct PaymentHistoryInnerPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var transactions: [PaymentTransactionItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case transactions = "data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        if let list = try? container.decode([PaymentTransactionItem].self, forKey: .transactions) {
            transactions = list
        } else if let emptyObject = try? container.decode([String: JSONValue].self, forKey: .transactions),
                  emptyObject.isEmpty {
            transactions = []
        } else {
            transactions = []
        }
    }
}

struct PaymentInsightsSummary: Decodable {
    var totalTransactions: Int
    var totalTransactionAmount: Double
    var averageTransactionValue: Double
    var amountByStatus: [String: Double]
    var paymentModes: [String: Int]

    init(
        totalTransactions: Int = 0,
        totalTransactionAmount: Double = 0,
        averageTransactionValue: Double = 0,
        amountByStatus: [String: Double] = [:],
        paymentModes: [String: Int] = [:]
    ) {
        self.totalTransactions = totalTransactions
        self.totalTransactionAmount = totalTransactionAmount
        self.averageTransactionValue = averageTransactionValue
        self.amountByStatus = amountByStatus
        self.paymentModes = paymentModes
    }

    init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)
        self = PaymentInsightsSummary(json: json) ?? PaymentInsightsSummary()
    }

    init?(json: JSONValue) {
        guard case .object(let object) = json else { return nil }

        totalTransactions = json.int(
            for: "totalTransactions", "total_transactions", "TotalTransactions"
        )
        totalTransactionAmount = json.double(
            for: "totalTransactionAmount", "total_transaction_amount", "TotalTransactionAmount"
        )
        averageTransactionValue = json.double(
            for: "averageTransactionValue", "average_transaction_value", "AverageTransactionValue"
        )

        amountByStatus = Self.parseAmountMap(
            object["amountByStatus"]
                ?? object["amount_by_status"]
                ?? object["AmountByStatus"]
        )
        if amountByStatus.isEmpty {
            amountByStatus = Self.parseDashboardTransactionsStyle(object)
        }
        if amountByStatus.isEmpty {
            amountByStatus = Self.parseAmountMap(
                object["paymentModes"]
                    ?? object["payment_modes"]
                    ?? object["PaymentModes"]
            )
        }

        paymentModes = Self.parseCountMap(
            object["paymentModes"]
                ?? object["payment_modes"]
                ?? object["PaymentModes"]
        )

        if totalTransactionAmount == 0, !amountByStatus.isEmpty {
            totalTransactionAmount = amountByStatus.values.reduce(0, +)
        }

        if totalTransactions == 0 {
            let billCount = json.int(for: "totalBillCount", "Total_Bill_Count", "total_bill_count")
            if billCount > 0 {
                totalTransactions = billCount
            } else if !paymentModes.isEmpty {
                totalTransactions = paymentModes.values.reduce(0, +)
            }
        }

        if averageTransactionValue == 0, totalTransactions > 0, totalTransactionAmount > 0 {
            averageTransactionValue = totalTransactionAmount / Double(totalTransactions)
        }
    }

    static func parse(from container: KeyedDecodingContainer<PaymentHistoryResponse.CodingKeys>, page: PaymentHistoryPage) -> PaymentInsightsSummary? {
        let rootKeys: [PaymentHistoryResponse.CodingKeys] = [.summary, .Summary]
        for key in rootKeys {
            if let json = try? container.decode(JSONValue.self, forKey: key),
               case .object = json {
                return PaymentInsightsSummary(json: json)
            }
        }

        if let dataJSON = try? container.decode(JSONValue.self, forKey: .data) {
            for summaryKey in ["summary", "Summary"] {
                if let summaryJSON = dataJSON[summaryKey],
                   case .object = summaryJSON {
                    return PaymentInsightsSummary(json: summaryJSON)
                }
            }

            if let nestedSummary = dataJSON["data"]?["summary"],
               case .object = nestedSummary {
                return PaymentInsightsSummary(json: nestedSummary)
            }

            if let dashboardSummary = PaymentInsightsSummary(json: dataJSON),
               dashboardSummary.hasMeaningfulData {
                return dashboardSummary
            }
        }

        if page.total > 0 || !page.transactions.isEmpty {
            return computeFallback(from: page)
        }

        return nil
    }

    var hasMeaningfulData: Bool {
        totalTransactions > 0
            || totalTransactionAmount > 0
            || !amountByStatus.isEmpty
            || !paymentModes.isEmpty
    }

    private static func computeFallback(from page: PaymentHistoryPage) -> PaymentInsightsSummary {
        var amountByStatus: [String: Double] = [:]
        var paymentModes: [String: Int] = [:]
        var totalAmount = 0.0

        for transaction in page.transactions {
            totalAmount += transaction.amount
            let modeName = PaymentInsightsPaymentMode.title(for: transaction.paymentMode)
            amountByStatus[modeName, default: 0] += transaction.amount
            paymentModes[modeName, default: 0] += 1
        }

        let totalTransactions = page.total > 0 ? page.total : page.transactions.count
        let average = totalTransactions > 0 ? totalAmount / Double(totalTransactions) : 0

        return PaymentInsightsSummary(
            totalTransactions: totalTransactions,
            totalTransactionAmount: totalAmount,
            averageTransactionValue: average,
            amountByStatus: amountByStatus,
            paymentModes: paymentModes
        )
    }

    private static func parseAmountMap(_ value: JSONValue?) -> [String: Double] {
        guard let value else { return [:] }

        if case .object(let object) = value {
            var map: [String: Double] = [:]
            for (key, item) in object {
                let normalizedKey = normalizePaymentModeKey(key)
                guard !normalizedKey.isEmpty else { continue }
                let amount = item.doubleValue
                guard amount > 0 else { continue }
                map[normalizedKey, default: 0] += amount
            }
            return map.filter { $0.value > 0 }
        }

        if case .array(let items) = value {
            var map: [String: Double] = [:]
            for item in items {
                guard case .object = item else { continue }
                let key = item.string(
                    for: "payment_mode", "paymentMode", "mode", "status", "label", "name", "key"
                )
                let amount = item.double(
                    for: "amount", "total_amount", "totalAmount", "value", "total"
                )
                let normalizedKey = normalizePaymentModeKey(key)
                guard !normalizedKey.isEmpty, amount > 0 else { continue }
                map[normalizedKey, default: 0] += amount
            }
            return map
        }

        return [:]
    }

    private static func parseCountMap(_ value: JSONValue?) -> [String: Int] {
        guard let value, case .object(let object) = value else { return [:] }

        var map: [String: Int] = [:]
        for (key, item) in object {
            let normalizedKey = normalizePaymentModeKey(key)
            guard !normalizedKey.isEmpty else { continue }
            map[normalizedKey, default: 0] += item.intValue
        }
        return map.filter { $0.value > 0 }
    }

    private static func parseDashboardTransactionsStyle(_ object: [String: JSONValue]) -> [String: Double] {
        let buckets = ["Approved", "Pending", "Rejected", "approved", "pending", "rejected"]
        let modeAmountKeys = [
            ("Cash", ["CashAmount", "cash_amount", "cashAmount"]),
            ("UPI", ["UPIAmount", "upi_amount", "upiAmount"]),
            ("Cheque", ["ChequeAmount", "cheque_amount", "chequeAmount"])
        ]

        var map: [String: Double] = [:]
        for bucket in buckets {
            guard let bucketObject = object[bucket]?.objectValue else { continue }
            for (mode, keys) in modeAmountKeys {
                let amount = keys.reduce(0.0) { partial, key in
                    partial + (bucketObject[key]?.doubleValue ?? 0)
                }
                if amount > 0 {
                    map[mode, default: 0] += amount
                }
            }
        }
        return map
    }

    private static func normalizePaymentModeKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch trimmed.lowercased() {
        case "cash", "cashamount", "cash_amount":
            return "Cash"
        case "upi", "upiamount", "upi_amount":
            return "UPI"
        case "cheque", "chequeamount", "cheque_amount", "check":
            return "Cheque"
        case "total_bill_count", "totalbillcount", "bills_with_settlements":
            return ""
        default:
            if trimmed.lowercased().hasSuffix("amount") {
                return normalizePaymentModeKey(String(trimmed.dropLast(6)))
            }
            return trimmed.capitalized
        }
    }
}

struct PaymentTransactionItem: Identifiable, Decodable, Hashable {
    var id: Int
    var orderNo: String
    var transactionNo: String
    var amount: Double
    var deductAmount: Double
    var date: String
    var sellerName: String
    var sellerPhone: String
    var staffName: String
    var paymentMode: String
    var status: String
    var orderStatus: String
    var sellerId: String

    enum CodingKeys: String, CodingKey {
        case id, amount, date, status
        case orderNo = "order_no"
        case transactionNo = "transaction_no"
        case deductAmount = "deduct_amount"
        case sellerName = "seller_name"
        case sellerPhone = "seller_mobile"
        case staffName = "staff_name"
        case paymentMode = "payment_mode"
        case orderStatus = "order_status"
        case sellerId = "seller_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        transactionNo = container.decodeStringLeniently(forKey: .transactionNo) ?? ""
        amount = container.decodeDoubleLeniently(forKey: .amount)
            ?? Double(container.decodeStringLeniently(forKey: .amount) ?? "") ?? 0
        deductAmount = container.decodeDoubleLeniently(forKey: .deductAmount)
            ?? Double(container.decodeStringLeniently(forKey: .deductAmount) ?? "") ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        sellerPhone = container.decodeStringLeniently(forKey: .sellerPhone) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
    }
}

struct BillSettlementHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var page: BillSettlementPage

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        page = (try? container.decode(BillSettlementPage.self, forKey: .data)) ?? BillSettlementPage()
    }
}

struct BillSettlementPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var settlements: [BillSettlementItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case inner = "data"
    }

    init(currentPage: Int = 0, lastPage: Int = 0, total: Int = 0, settlements: [BillSettlementItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.settlements = settlements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0

        if let inner = try? container.decode(BillSettlementInnerPage.self, forKey: .inner) {
            currentPage = inner.currentPage > 0 ? inner.currentPage : currentPage
            lastPage = inner.lastPage > 0 ? inner.lastPage : lastPage
            total = inner.total > 0 ? inner.total : total
            settlements = inner.settlements
        } else {
            settlements = []
        }
    }
}

private struct BillSettlementInnerPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var settlements: [BillSettlementItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case settlements = "data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        settlements = (try? container.decode([BillSettlementItem].self, forKey: .settlements)) ?? []
    }
}

struct BillSettlementItem: Identifiable, Decodable, Hashable {
    var id: Int
    var billId: String
    var date: String
    var orderId: String
    var paymentMode: String
    var deductAmount: Double
    var sellerName: String
    var sellerPhone: String
    var staffName: String
    var discount: String
    var imageUrl: String

    enum CodingKeys: String, CodingKey {
        case id, date, discount
        case billId = "bill_id"
        case orderId = "order_id"
        case paymentMode = "payment_mode"
        case deductAmount = "deduct_amount"
        case sellerName = "seller_name"
        case sellerPhone = "seller_mobile"
        case staffName = "staff_name"
        case imageUrl = "image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        billId = container.decodeStringLeniently(forKey: .billId) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        deductAmount = container.decodeDoubleLeniently(forKey: .deductAmount)
            ?? Double(container.decodeStringLeniently(forKey: .deductAmount) ?? "") ?? 0
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        sellerPhone = container.decodeStringLeniently(forKey: .sellerPhone) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        discount = container.decodeStringLeniently(forKey: .discount) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .imageUrl) ?? ""
    }
}
