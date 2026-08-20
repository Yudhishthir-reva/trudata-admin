//
//  AssignBeatModels.swift
//  Truedata
//

import Foundation

struct AssignedBeatListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [AssignedBeatStaffItem]

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
        data = (try? container.decode([AssignedBeatStaffItem].self, forKey: .data)) ?? []
    }
}

struct AssignedBeatStaffItem: Identifiable, Hashable, Decodable {
    var id: String { staffId }
    var staffName: String
    var staffId: String
    var beatCount: String
    var beatNames: String
    var beatData: [AssignedBeatDetailItem]

    enum CodingKeys: String, CodingKey {
        case staffName = "staff_name"
        case staffId = "staff_id"
        case beatCount = "beat_count"
        case beatNames = "beat_names"
        case beatData = "beat_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        beatCount = container.decodeStringLeniently(forKey: .beatCount) ?? "0"
        beatNames = container.decodeStringLeniently(forKey: .beatNames) ?? ""
        beatData = (try? container.decode([AssignedBeatDetailItem].self, forKey: .beatData)) ?? []
    }

    var activeBeatCount: Int {
        beatData.filter(\.isActive).count
    }
}

struct AssignedBeatDetailItem: Identifiable, Hashable, Decodable {
    var id: String { assignBeatId }
    var assignBeatId: String
    var beatId: String
    var beatName: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case assignBeatId = "assign_beat_id"
        case beatId = "beat_id"
        case beatName = "beat_name"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assignBeatId = container.decodeStringLeniently(forKey: .assignBeatId) ?? ""
        beatId = container.decodeStringLeniently(forKey: .beatId) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? "0"
    }

    var isActive: Bool { status == "1" }
}

struct AssignBeatFormState: Equatable {
    var selectedStaffId: String = ""
    var selectedStaffName: String = ""
    var selectedBeatIds: Set<String> = []

    var isValid: Bool {
        !selectedStaffId.isEmpty && !selectedBeatIds.isEmpty
    }

    mutating func reset() {
        selectedStaffId = ""
        selectedStaffName = ""
        selectedBeatIds = []
    }
}

enum AssignBeatStaffFilter {
    static func isEligible(_ staff: RegisteredStaffMember) -> Bool {
        let role = staff.roleId.trimmingCharacters(in: .whitespacesAndNewlines)
        return role.caseInsensitiveCompare("Sale Person") == .orderedSame
            || role == "5"
            || role.caseInsensitiveCompare("Accountant") == .orderedSame
    }
}
