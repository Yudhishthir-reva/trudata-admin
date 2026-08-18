//
//  SellerPaymentModels.swift
//  Truedata
//

import Foundation
import UIKit

struct PaymentBillListResponse: Decodable {
    var status: Bool
    var message: String
    var data: PaymentBillListData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(PaymentBillListData.self, forKey: .data)) ?? PaymentBillListData()
    }
}

struct PaymentBillListData: Decodable {
    var billList: [PaymentBillItem]
    var pendingAmt: String

    enum CodingKeys: String, CodingKey {
        case billList, pendingAmt
    }

    init(billList: [PaymentBillItem] = [], pendingAmt: String = "") {
        self.billList = billList
        self.pendingAmt = pendingAmt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        billList = (try? container.decode([PaymentBillItem].self, forKey: .billList)) ?? []
        pendingAmt = container.decodeStringLeniently(forKey: .pendingAmt) ?? ""
    }
}

struct PaymentBillItem: Decodable, Identifiable {
    var id: Int
    var orderId: String
    var amount: String
    var deductAmount: String
    var date: String
    var paymentMode: String
    var status: String
    var orderStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case amount
        case deductAmount = "deduct_amount"
        case date
        case paymentMode = "payment_mode"
        case status
        case orderStatus = "order_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? ""
        deductAmount = container.decodeStringLeniently(forKey: .deductAmount) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? ""
    }

    var paymentModeLabel: String {
        switch paymentMode {
        case "1": return "Cash"
        case "2": return "Cheque"
        case "3": return "UPI"
        default: return "N/A"
        }
    }

    var deductAmountValue: Double {
        Double(deductAmount) ?? 0
    }
}

enum SellerPaymentMode: Int, CaseIterable, Identifiable {
    case cash = 1
    case upi = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .cash: return "Cash"
        case .upi: return "UPI/Online"
        }
    }

    var iconName: String {
        switch self {
        case .cash: return "banknote.fill"
        case .upi: return "qrcode"
        }
    }
}

enum PaymentImageCompression {
    static func compressJPEG(_ data: Data, targetKB: Int = 200) -> Data {
        guard let image = UIImage(data: data) else { return data }
        var quality: CGFloat = 0.85
        var compressed = image.jpegData(compressionQuality: quality) ?? data
        while compressed.count > targetKB * 1024 && quality > 0.15 {
            quality -= 0.1
            if let next = image.jpegData(compressionQuality: quality) {
                compressed = next
            } else {
                break
            }
        }
        return compressed
    }
}
