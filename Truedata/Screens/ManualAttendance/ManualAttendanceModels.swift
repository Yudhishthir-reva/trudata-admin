//
//  ManualAttendanceModels.swift
//  Truedata
//

import Foundation
import SwiftUI

/// `attendance_type` on the manual-attendance endpoints. The server accepts only these five codes.
/// Mirrors Android `AttendanceType`.
enum ManualAttendanceType: Int, CaseIterable, Identifiable, Hashable {
    case present = 1
    case absent = 2
    case firstHalf = 3
    case secondHalf = 4
    case holiday = 5

    var id: Int { rawValue }

    init?(code: Int?) {
        guard let code, let value = ManualAttendanceType(rawValue: code) else { return nil }
        self = value
    }

    var label: String {
        switch self {
        case .present: return "Present (Full Day)"
        case .absent: return "Absent"
        case .firstHalf: return "Half Day · First Half"
        case .secondHalf: return "Half Day · Second Half"
        case .holiday: return "Holiday"
        }
    }

    var shortLabel: String {
        switch self {
        case .present: return "Present"
        case .absent: return "Absent"
        case .firstHalf: return "1st Half"
        case .secondHalf: return "2nd Half"
        case .holiday: return "Holiday"
        }
    }

    /// One line that says what a status means, for the guide and the detail sheet.
    var meaning: String {
        switch self {
        case .present: return "Worked the full day"
        case .absent: return "Did not come in"
        case .firstHalf: return "Worked only the morning half"
        case .secondHalf: return "Worked only the afternoon half"
        case .holiday: return "Paid holiday for this day"
        }
    }

    var tint: Color {
        switch self {
        case .present: return Color(hex: "15803D")
        case .absent: return Color(hex: "DC2626")
        case .firstHalf: return Color(hex: "D97706")
        case .secondHalf: return Color(hex: "2563EB")
        case .holiday: return Color(hex: "7C3AED")
        }
    }

    var icon: String {
        switch self {
        case .present: return "checkmark.circle.fill"
        case .absent: return "xmark.circle.fill"
        case .firstHalf: return "sunrise.fill"
        case .secondHalf: return "sunset.fill"
        case .holiday: return "party.popper.fill"
        }
    }
}

/// Shown where nothing is marked yet: grey, never a status colour, so it can't be mistaken for one.
enum ManualAttendanceStyle {
    static let unmarked = Color(hex: "9CA3AF")
    static let page = Color(hex: "F7F9F8")
    static let card = Color.white
    static let border = Color(hex: "E4E7EB")
    static let track = Color(hex: "F3F5F7")
    static let text = Color(hex: "111827")
    static let textMuted = Color(hex: "6B7280")
    static let textFaint = Color(hex: "9CA3AF")
    static let warn = Color(hex: "B45309")
    static let info = Color(hex: "0369A1")
    static let infoBg = Color(hex: "E0F2FE")
    static let container = Color(hex: "E8F5EE")
}

/// Mark anyone's attendance by hand and read what was marked: admin, accounts, sales manager.
/// Mirrors Android `CashAccess.canManageAttendance`. The server enforces the same split (403).
enum ManualAttendanceAccess {
    static func allowed(role: String) -> Bool {
        ["admin", "accountant", "sales manager", "sale manager"]
            .contains(role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static var currentUserAllowed: Bool {
        allowed(role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole))
    }
}

// MARK: - Responses

/// `manual-attendance/staff-list`: everyone but the caller, with what is already marked for the day.
struct ManualAttendanceStaffListResponse: Decodable {
    var status: Bool
    var message: String
    var data: ManualAttendanceDay

    enum CodingKeys: String, CodingKey { case status, message, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeMessageLeniently(forKey: .message)
        data = (try? container.decode(ManualAttendanceDay.self, forKey: .data)) ?? ManualAttendanceDay()
    }
}

struct ManualAttendanceDay: Decodable {
    var date: String = ""
    /// Sundays: `staff` comes back empty and the mark endpoint refuses the date.
    var isWeeklyOff: Bool = false
    var weeklyOffMessage: String?
    var staff: [ManualAttendanceStaff] = []

    enum CodingKeys: String, CodingKey {
        case date, staff
        case isWeeklyOff = "is_weekly_off"
        case weeklyOffMessage = "weekly_off_message"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        isWeeklyOff = container.decodeBoolLeniently(forKey: .isWeeklyOff) ?? false
        weeklyOffMessage = container.decodeStringLeniently(forKey: .weeklyOffMessage)
        staff = (try? container.decode([ManualAttendanceStaff].self, forKey: .staff)) ?? []
    }
}

struct ManualAttendanceStaff: Decodable, Identifiable, Hashable {
    var userID: Int = 0
    var name: String = ""
    var designation: String?
    var profileImage: String?
    /// Nil until someone marks it; otherwise a ``ManualAttendanceType`` code.
    var attendanceType: Int?

    var id: Int { userID }

    enum CodingKeys: String, CodingKey {
        case name
        case userID = "user_id"
        case designation
        case profileImage = "profile_image"
        case attendanceType = "attendance_type"
    }

    init(userID: Int = 0, name: String = "", designation: String? = nil, profileImage: String? = nil, attendanceType: Int? = nil) {
        self.userID = userID
        self.name = name
        self.designation = designation
        self.profileImage = profileImage
        self.attendanceType = attendanceType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = container.decodeIntLeniently(forKey: .userID) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        designation = container.decodeStringLeniently(forKey: .designation)
        profileImage = container.decodeStringLeniently(forKey: .profileImage)
        attendanceType = container.decodeIntLeniently(forKey: .attendanceType)
    }
}

/// `manual-attendance/history`: only the people someone has marked for the day.
struct ManualAttendanceHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var records: [ManualAttendanceRecord]

    enum CodingKeys: String, CodingKey { case status, message, data }
    private enum DataKeys: String, CodingKey { case date, records }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeMessageLeniently(forKey: .message)
        let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        records = (try? data?.decode([ManualAttendanceRecord].self, forKey: .records)) ?? []
    }
}

struct ManualAttendanceRecord: Decodable, Identifiable {
    var id: Int { userID }

    var userID: Int = 0
    var name: String = ""
    var attendanceType: Int = 0
    var attendanceTypeLabel: String?
    /// A user id; the name comes from the staff list.
    var markedBy: Int?
    var date: String = ""

    enum CodingKeys: String, CodingKey {
        case name, date
        case userID = "user_id"
        case attendanceType = "attendance_type"
        case attendanceTypeLabel = "attendance_type_label"
        case markedBy = "marked_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = container.decodeIntLeniently(forKey: .userID) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        attendanceType = container.decodeIntLeniently(forKey: .attendanceType) ?? 0
        attendanceTypeLabel = container.decodeStringLeniently(forKey: .attendanceTypeLabel)
        markedBy = container.decodeIntLeniently(forKey: .markedBy)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
    }
}

/// `manual-attendance/mark`. Once the server says it saved, that stands even if `data` can't be read.
struct ManualAttendanceMarkResponse: Decodable {
    var status: Bool
    var message: String
    var count: Int?

    enum CodingKeys: String, CodingKey { case status, message, data }
    private enum DataKeys: String, CodingKey { case date, count }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeMessageLeniently(forKey: .message)
        let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        count = data?.decodeIntLeniently(forKey: .count)
    }
}

// MARK: - Dates

enum ManualAttendanceDate {
    /// `yyyy-MM-dd`, what every manual-attendance endpoint takes.
    static let api: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let long: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy"
        return formatter
    }()

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func day(_ date: Date) -> String { api.string(from: date) }
    static func longLabel(_ date: Date) -> String { long.string(from: date) }

    static func parse(_ text: String) -> Date? { api.date(from: text) }

    static var today: Date { calendar.startOfDay(for: Date()) }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func isWeeklyOff(_ date: Date) -> Bool { calendar.component(.weekday, from: date) == 1 }

    /// "Today", "Tomorrow", "In 3 days", "Yesterday" or the weekday, for the line under a date.
    static func relativeLabel(_ date: Date, today: Date = ManualAttendanceDate.today) -> String {
        let days = calendar.dateComponents([.day], from: today, to: startOfDay(date)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...6: return "In \(days) days"
        default: return weekday.string(from: date)
        }
    }
}

extension KeyedDecodingContainer {
    /// `message` is a string on some endpoints and an array of strings on others.
    func decodeMessageLeniently(forKey key: Key) -> String {
        if let list = try? decodeIfPresent([String].self, forKey: key) {
            return list.first ?? ""
        }
        return decodeStringLeniently(forKey: key) ?? ""
    }
}
