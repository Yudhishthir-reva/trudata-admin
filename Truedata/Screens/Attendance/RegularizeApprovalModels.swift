//
//  RegularizeApprovalModels.swift
//  Truedata
//

import Foundation

struct RegularizeTeamWiseListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [RegularizeTeamWiseItem]

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
        data = (try? container.decode([RegularizeTeamWiseItem].self, forKey: .data)) ?? []
    }
}

struct RegularizeTeamWiseItem: Identifiable, Hashable, Decodable {
    var id: Int
    var userId: String
    var staffId: String
    var name: String
    var role: String
    var remark: String
    var date: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, name, role, remark, date, status
        case userId = "user_id"
        case staffId = "staff_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        userId = container.decodeStringLeniently(forKey: .userId) ?? ""
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        role = container.decodeStringLeniently(forKey: .role) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
    }

    var displayName: String {
        role.isEmpty ? name : "\(name) (\(role))"
    }

    var statusTab: AttendanceRequestTab {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "approved": return .approved
        case "rejected": return .rejected
        default: return .pending
        }
    }
}

struct RegularizeStatusAction {
    var regularizeId: Int
    var staffId: String
    var staffName: String
    var approve: Bool

    var title: String {
        approve ? "Approve Regularization?" : "Reject Request?"
    }

    var message: String {
        let verb = approve ? "approve" : "reject"
        return "Are you sure you want to \(verb) this request for \(staffName)?"
    }

    var statusValue: String {
        approve ? "1" : "2"
    }
}
