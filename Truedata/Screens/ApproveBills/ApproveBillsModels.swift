//
//  ApproveBillsModels.swift
//  Truedata
//

import Foundation

struct RiderPendingBillsResponse: Decodable {
    var success: Bool
    var message: String
    var data: [PendingBillItem]

    enum CodingKeys: String, CodingKey {
        case success, message, data, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boolStatus = container.decodeBoolLeniently(forKey: .success) {
            success = boolStatus
        } else {
            success = container.decodeBoolLeniently(forKey: .status) ?? false
        }
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode([PendingBillItem].self, forKey: .data)) ?? []
    }
}

struct PendingBillItem: Decodable, Identifiable, Hashable {
    var id: Int
    var amount: String
    var date: String
    var image: String
    var orderId: String
    var riderName: String
    var sellerName: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, amount, date, image, status
        case orderId = "order_id"
        case riderName = "rider_name"
        case sellerName = "seller_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        image = container.decodeStringLeniently(forKey: .image) ?? ""
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        riderName = container.decodeStringLeniently(forKey: .riderName) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
    }
}
