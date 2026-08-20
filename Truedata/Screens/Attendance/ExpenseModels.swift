//
//  ExpenseModels.swift
//  Truedata
//

import Foundation

struct ExpenseItem: Identifiable, Hashable, Decodable {
    var id: Int
    var staffId: String
    var staffName: String
    var expenseAmount: String
    var expenseDate: String
    var remark: String
    var expenseImage: String?
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, remark, status
        case staffId = "staff_id"
        case staffName = "staff_name"
        case expenseAmount = "expense_amount"
        case expenseDate = "expense_date"
        case expenseImage = "expense_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        expenseAmount = container.decodeStringLeniently(forKey: .expenseAmount) ?? "0"
        expenseDate = container.decodeStringLeniently(forKey: .expenseDate) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        expenseImage = container.decodeStringLeniently(forKey: .expenseImage)
        status = container.decodeStringLeniently(forKey: .status) ?? "0"
    }

    var amountLabel: String {
        expenseAmount.priceLabel
    }

    var statusTab: AttendanceRequestTab {
        switch status {
        case "1": return .approved
        case "2": return .rejected
        default: return .pending
        }
    }

    var statusLabel: String {
        switch status {
        case "1": return "Approved"
        case "2": return "Rejected"
        case "0": return "Pending"
        default: return status.capitalized
        }
    }

    var hasImage: Bool {
        guard let expenseImage else { return false }
        return !expenseImage.isEmptyString
    }
}

struct ExpenseListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [ExpenseItem]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([ExpenseItem].self, forKey: .data)) ?? []
    }
}

struct ExpenseStatusAction {
    var expenseId: Int
    var staffId: String
    var staffName: String
    var amount: String
    var remark: String
    var approve: Bool

    var title: String {
        approve ? "Confirm Approval" : "Confirm Rejection"
    }

    var message: String {
        let remarkText = remark.isEmptyString ? "N/A" : remark
        let verb = approve ? "Approve" : "Reject"
        return "\(verb) expense request of \(amount) for \(staffName) (Remark: \(remarkText))?"
    }

    var statusValue: String {
        approve ? "1" : "2"
    }
}
