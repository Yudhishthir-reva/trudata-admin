//
//  LeaveModels.swift
//  Truedata
//

import Foundation

struct LeaveListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [LeaveItem]

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
        data = (try? container.decode([LeaveItem].self, forKey: .data)) ?? []
    }
}

struct LeaveItem: Identifiable, Decodable, Hashable {
    var id: Int
    var startDate: String
    var endDate: String
    var leaveType: String
    var remark: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, remark, status
        case startDate = "start_date"
        case endDate = "end_date"
        case leaveType = "leave_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        startDate = container.decodeStringLeniently(forKey: .startDate) ?? ""
        endDate = container.decodeStringLeniently(forKey: .endDate) ?? ""
        leaveType = container.decodeStringLeniently(forKey: .leaveType) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
    }
}

struct LeaveTypeListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [LeaveTypeItem]

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
        data = (try? container.decode([LeaveTypeItem].self, forKey: .data)) ?? []
    }
}

struct LeaveTypeItem: Identifiable, Decodable, Hashable {
    var id: Int
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}
