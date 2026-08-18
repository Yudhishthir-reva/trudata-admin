//
//  ViewPendingBillsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

struct PendingPaymentBillsResponse: Decodable {
    var status: Bool
    var message: String
    var data: PendingPaymentBillsData

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
        data = (try? container.decode(PendingPaymentBillsData.self, forKey: .data)) ?? PendingPaymentBillsData()
    }
}

struct PendingPaymentBillsData: Decodable {
    var currentPage: Int
    var lastPage: Int
    var perPage: Int
    var total: Int
    var response: PendingPaymentBillsResponseBody
    var paymentModeMap: [PaymentLookupItem]
    var paymentStatusMap: [PaymentLookupItem]
    var orderStatusMap: [PaymentLookupItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total, response
        case paymentModeMap = "payment_mode_map"
        case paymentStatusMap = "payment_status_map"
        case orderStatusMap = "order_status_map"
    }

    init(
        currentPage: Int = 0,
        lastPage: Int = 0,
        perPage: Int = 0,
        total: Int = 0,
        response: PendingPaymentBillsResponseBody = PendingPaymentBillsResponseBody(),
        paymentModeMap: [PaymentLookupItem] = [],
        paymentStatusMap: [PaymentLookupItem] = [],
        orderStatusMap: [PaymentLookupItem] = []
    ) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.perPage = perPage
        self.total = total
        self.response = response
        self.paymentModeMap = paymentModeMap
        self.paymentStatusMap = paymentStatusMap
        self.orderStatusMap = orderStatusMap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        response = (try? container.decode(PendingPaymentBillsResponseBody.self, forKey: .response))
            ?? PendingPaymentBillsResponseBody()
        paymentModeMap = (try? container.decode([PaymentLookupItem].self, forKey: .paymentModeMap)) ?? []
        paymentStatusMap = (try? container.decode([PaymentLookupItem].self, forKey: .paymentStatusMap)) ?? []
        orderStatusMap = (try? container.decode([PaymentLookupItem].self, forKey: .orderStatusMap)) ?? []
    }
}

struct PendingPaymentBillsResponseBody: Decodable {
    var billList: PendingPaymentBillList

    enum CodingKeys: String, CodingKey {
        case billList
    }

    init(billList: PendingPaymentBillList = PendingPaymentBillList()) {
        self.billList = billList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        billList = (try? container.decode(PendingPaymentBillList.self, forKey: .billList))
            ?? PendingPaymentBillList()
    }
}

struct PendingPaymentBillList: Decodable {
    var currentPage: Int
    var lastPage: Int
    var data: [PendingPaymentBill]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case data
    }

    init(currentPage: Int = 0, lastPage: Int = 0, data: [PendingPaymentBill] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        data = (try? container.decode([PendingPaymentBill].self, forKey: .data)) ?? []
    }
}

struct PendingPaymentBill: Decodable, Identifiable, Hashable {
    var id: Int
    var transactionNo: String
    var orderDate: String
    var amount: String
    var remainingAmount: String
    var paymentStatus: String
    var paymentMode: String
    var sellerName: String
    var staffName: String
    var orderId: String
    var orderStatus: String
    var history: [PendingPaymentBillHistory]

    enum CodingKeys: String, CodingKey {
        case id, amount, history
        case transactionNo
        case orderDate
        case remainingAmount
        case paymentStatus
        case paymentMode
        case sellerName
        case staffName
        case orderId
        case orderStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        transactionNo = container.decodeStringLeniently(forKey: .transactionNo) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        remainingAmount = container.decodeStringLeniently(forKey: .remainingAmount) ?? "0"
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? ""
        history = (try? container.decode([PendingPaymentBillHistory].self, forKey: .history)) ?? []
    }

    var displayOrderId: String {
        orderId.isEmptyString ? transactionNo : orderId
    }

    var remainingValue: Double {
        Double(remainingAmount) ?? 0
    }
}

struct PendingPaymentBillHistory: Decodable, Identifiable, Hashable {
    var id: Int { serialNumber }
    var serialNumber: Int
    var date: String
    var paymentMode: String?
    var payAmount: String
    var staff: String
    var seller: String

    enum CodingKeys: String, CodingKey {
        case serialNumber = "S_No"
        case date = "Date"
        case paymentMode
        case payAmount
        case staff, seller
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serialNumber = container.decodeIntLeniently(forKey: .serialNumber) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode)
        payAmount = container.decodeStringLeniently(forKey: .payAmount) ?? "0"
        staff = container.decodeStringLeniently(forKey: .staff) ?? ""
        seller = container.decodeStringLeniently(forKey: .seller) ?? ""
    }
}

struct PaymentLookupItem: Decodable, Identifiable, Hashable {
    var id: Int { key }
    var key: Int
    var label: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeIntLeniently(forKey: .key) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case key, label
    }
}

enum BillPaymentStatus: String {
    case pending = "0"
    case remaining = "1"
    case complete = "2"
    case unknown = "-1"

    init(key: String?) {
        self = BillPaymentStatus(rawValue: key ?? "") ?? .unknown
    }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .remaining: return "Remaining"
        case .complete: return "Complete"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .pending: return DashboardTheme.warningYellow
        case .remaining: return DashboardTheme.infoBlue
        case .complete: return DashboardTheme.successGreen
        case .unknown: return DashboardTheme.neutralMedium
        }
    }
}

enum BillPaymentMode: String {
    case na = "0"
    case cash = "1"
    case cheque = "2"
    case upi = "3"
    case unknown = "-1"

    init(key: String?) {
        self = BillPaymentMode(rawValue: key ?? "") ?? .unknown
    }

    var label: String {
        switch self {
        case .na: return "N/A"
        case .cash: return "Cash"
        case .cheque: return "Cheque"
        case .upi: return "UPI"
        case .unknown: return "Unknown"
        }
    }
}

enum BillOrderStatus: String {
    case pending = "0"
    case toDeliver = "1"
    case pickup = "2"
    case delivered = "3"
    case cancel = "4"
    case assign = "6"
    case deliveryFailed = "7"
    case partialReturn = "8"
    case unknown = "-1"

    init(key: String?) {
        self = BillOrderStatus(rawValue: key ?? "") ?? .unknown
    }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .toDeliver: return "To Deliver"
        case .pickup: return "Pickup"
        case .delivered: return "Delivered"
        case .cancel: return "Cancel"
        case .assign: return "Assign"
        case .deliveryFailed: return "Delivery Failed"
        case .partialReturn: return "Partial Return"
        case .unknown: return "Unknown"
        }
    }
}

struct PendingPaymentStatusTab: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var count: Int
}
