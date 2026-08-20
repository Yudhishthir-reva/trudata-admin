//
//  TargetModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum TargetAPIDateFormat {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static var currentMonth: String {
        monthFormatter.string(from: Date())
    }

    static func monthRange(for month: String) -> (start: String, end: String)? {
        guard let date = monthFormatter.date(from: month) else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startDate = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startDate),
              let endDate = calendar.date(byAdding: .day, value: range.count - 1, to: startDate) else {
            return nil
        }
        return (string(from: startDate), string(from: endDate))
    }

    static func defaultCreateRange() -> (month: String, start: String, end: String) {
        let month = currentMonth
        if let range = monthRange(for: month) {
            return (month, range.start, range.end)
        }
        let today = string(from: Date())
        return (month, today, today)
    }
}

enum SalesTargetStatus: String, CaseIterable, Identifiable {
    case inProgress = "1"
    case complete = "2"
    case incomplete = "3"
    case pending = "0"
    case cancelled = "4"
    case other = "5"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In-Progress"
        case .complete: return "Complete"
        case .incomplete: return "Incomplete"
        case .cancelled: return "Cancelled"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .pending: return Color(hex: "F59E0B")
        case .inProgress: return Color(hex: "3B82F6")
        case .complete: return DashboardTheme.successGreen
        case .incomplete: return Color(hex: "FD7E14")
        case .cancelled: return DashboardTheme.dangerRed
        case .other: return DashboardTheme.neutralMedium
        }
    }

    static func from(id: String) -> SalesTargetStatus {
        SalesTargetStatus(rawValue: id) ?? .other
    }
}

struct SalesTargetListResponse: Decodable {
    var status: Bool
    var message: String
    var data: SalesTargetPaginatedData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(SalesTargetPaginatedData.self, forKey: .data)) ?? SalesTargetPaginatedData()
    }
}

struct SalesTargetPaginatedData: Decodable {
    var currentPage: Int
    var lastPage: Int
    var targets: [SalesTargetItem]

    enum CodingKeys: String, CodingKey {
        case targets = "data"
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(currentPage: Int = 1, lastPage: Int = 1, targets: [SalesTargetItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.targets = targets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        targets = (try? container.decode([SalesTargetItem].self, forKey: .targets)) ?? []
    }

    var hasNextPage: Bool { currentPage < lastPage }
}

struct SalesTargetItem: Identifiable, Hashable, Decodable {
    var id: Int
    var staffId: String
    var targetAmount: String
    var achievedAmount: String
    var targetStartDate: String
    var targetEndDate: String
    var month: String
    var targetStatus: String
    var showTargetEditButton: Bool
    var staffName: String

    enum CodingKeys: String, CodingKey {
        case id, month, staff
        case staffId = "staff_id"
        case targetAmount = "target_amount"
        case achievedAmount = "achieved_amount"
        case targetStartDate = "target_start_date"
        case targetEndDate = "target_end_date"
        case targetStatus = "target_status"
        case showTargetEditButton = "show_target_edit_button"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        targetAmount = container.decodeStringLeniently(forKey: .targetAmount) ?? "0"
        achievedAmount = container.decodeStringLeniently(forKey: .achievedAmount) ?? "0"
        targetStartDate = container.decodeStringLeniently(forKey: .targetStartDate) ?? ""
        targetEndDate = container.decodeStringLeniently(forKey: .targetEndDate) ?? ""
        month = container.decodeStringLeniently(forKey: .month) ?? ""
        targetStatus = container.decodeStringLeniently(forKey: .targetStatus) ?? ""
        if let boolValue = try? container.decode(Bool.self, forKey: .showTargetEditButton) {
            showTargetEditButton = boolValue
        } else {
            showTargetEditButton = container.decodeStringLeniently(forKey: .showTargetEditButton) == "1"
        }
        if let staff = try? container.decode(SalesTargetStaff.self, forKey: .staff) {
            staffName = staff.name
        } else {
            staffName = "N/A"
        }
    }

    var status: SalesTargetStatus { SalesTargetStatus.from(id: targetStatus) }

    var progress: Double {
        let target = Double(targetAmount) ?? 0
        let achieved = Double(achievedAmount) ?? 0
        guard target > 0 else { return 0 }
        return min(max(achieved / target, 0), 1)
    }

    var durationText: String {
        "Duration - \(targetStartDate) - \(targetEndDate)"
    }
}

private struct SalesTargetStaff: Decodable {
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? "N/A"
    }

    enum CodingKeys: String, CodingKey {
        case name
    }
}

struct TargetFormData: Equatable {
    var targetId: Int?
    var staffId: String = ""
    var staffName: String = ""
    var targetAmount: String = ""
    var month: String = ""
    var targetStartDate: String = ""
    var targetEndDate: String = ""
    var targetStatus: String = "1"

    var isEditMode: Bool { targetId != nil }

    var isValid: Bool {
        !staffId.isEmpty
            && !targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !month.isEmpty
    }
}

struct TargetFilters: Equatable {
    var staffId: String = ""
    var staffName: String = ""
    var targetStatus: String = ""
    var month: String = ""

    var isActive: Bool {
        !staffId.isEmpty || !targetStatus.isEmpty || !month.isEmpty
    }
}

struct TargetStatusMessageResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
    }
}

struct TargetHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var data: TargetHistoryData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(TargetHistoryData.self, forKey: .data)
    }
}

struct TargetHistoryData: Decodable {
    var target: TargetHistoryDetails?
    var orders: [TargetHistoryOrder]

    enum CodingKeys: String, CodingKey {
        case target, orders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        target = try? container.decode(TargetHistoryDetails.self, forKey: .target)
        orders = (try? container.decode([TargetHistoryOrder].self, forKey: .orders)) ?? []
    }
}

struct TargetHistoryDetails: Decodable, Hashable {
    var id: Int
    var staffId: String
    var targetAmount: String
    var achievedAmount: String
    var targetStartDate: String
    var targetEndDate: String
    var month: String
    var targetStatus: String

    enum CodingKeys: String, CodingKey {
        case id, month
        case staffId = "staff_id"
        case targetAmount = "target_amount"
        case achievedAmount = "achieved_amount"
        case targetStartDate = "target_start_date"
        case targetEndDate = "target_end_date"
        case targetStatus = "target_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        targetAmount = container.decodeStringLeniently(forKey: .targetAmount) ?? "0"
        achievedAmount = container.decodeStringLeniently(forKey: .achievedAmount) ?? "0"
        targetStartDate = container.decodeStringLeniently(forKey: .targetStartDate) ?? ""
        targetEndDate = container.decodeStringLeniently(forKey: .targetEndDate) ?? ""
        month = container.decodeStringLeniently(forKey: .month) ?? ""
        targetStatus = container.decodeStringLeniently(forKey: .targetStatus) ?? ""
    }

    var status: SalesTargetStatus { SalesTargetStatus.from(id: targetStatus) }

    var progress: Double {
        let target = Double(targetAmount) ?? 0
        let achieved = Double(achievedAmount) ?? 0
        guard target > 0 else { return 0 }
        return min(max(achieved / target, 0), 1)
    }
}

struct TargetHistoryOrder: Identifiable, Hashable, Decodable {
    var id: Int
    var date: String
    var orderId: String
    var status: String
    var totalPrice: String

    enum CodingKeys: String, CodingKey {
        case id, date, status
        case orderId = "order_id"
        case totalPrice = "total_price"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
    }
}

struct TargetHistoryContext: Identifiable, Hashable {
    var id: Int { targetId }
    var targetId: Int
    var staffName: String
}
