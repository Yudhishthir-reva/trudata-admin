//
//  RegularizationModels.swift
//  Truedata
//

import Foundation

struct RegularizationListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [RegularizationItem]

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
        data = (try? container.decode([RegularizationItem].self, forKey: .data)) ?? []
    }
}

struct RegularizationItem: Identifiable, Decodable, Hashable {
    var id: Int
    var date: String
    var remark: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, date, remark, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
    }
}
