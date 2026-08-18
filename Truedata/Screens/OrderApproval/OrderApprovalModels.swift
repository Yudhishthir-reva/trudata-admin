//
//  OrderApprovalModels.swift
//  Truedata
//

import Foundation

struct OrderApprovalListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [OrderApprovalItem]
    var statusCount: [OrderApprovalStatusTab]

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case statusCount = "statusCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode([OrderApprovalItem].self, forKey: .data)) ?? []
        statusCount = (try? container.decode([OrderApprovalStatusTab].self, forKey: .statusCount)) ?? []
    }
}

struct OrderApprovalStatusTab: Decodable, Identifiable, Hashable {
    var id: Int { key }
    var key: Int
    var label: String
    var count: Int

    enum CodingKeys: String, CodingKey {
        case key, label, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeIntLeniently(forKey: .key) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? "Unknown"
        count = container.decodeIntLeniently(forKey: .count) ?? 0
    }

    init(key: Int, label: String, count: Int) {
        self.key = key
        self.label = label
        self.count = count
    }
}

struct OrderApprovalItem: Decodable, Identifiable, Hashable {
    var id: Int
    var shopName: String
    var seller: String
    var sellerId: Int
    var staff: String
    var staffId: Int
    var status: String
    var pendingBills: Int
    var createdAt: String
    var isRequestUsed: String

    var isPending: Bool { status == "0" }

    enum CodingKeys: String, CodingKey {
        case id, seller, staff, status
        case shopName = "shop_name"
        case sellerId = "seller_id"
        case staffId = "staff_id"
        case pendingBills = "pending_bills"
        case createdAt = "created_at"
        case isRequestUsed = "is_request_used"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        seller = container.decodeStringLeniently(forKey: .seller) ?? ""
        sellerId = container.decodeIntLeniently(forKey: .sellerId) ?? 0
        staff = container.decodeStringLeniently(forKey: .staff) ?? ""
        staffId = container.decodeIntLeniently(forKey: .staffId) ?? 0
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        pendingBills = container.decodeIntLeniently(forKey: .pendingBills) ?? 0
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
        isRequestUsed = container.decodeStringLeniently(forKey: .isRequestUsed) ?? ""
    }

    var formattedDate: String {
        guard !createdAt.isEmptyString else { return "-" }
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"
        input.locale = Locale(identifier: "en_US_POSIX")
        let output = DateFormatter()
        output.dateStyle = .medium
        output.timeStyle = .short
        if let date = input.date(from: createdAt) {
            return output.string(from: date)
        }
        return createdAt
    }
}
