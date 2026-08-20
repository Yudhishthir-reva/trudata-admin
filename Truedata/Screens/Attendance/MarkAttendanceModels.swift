//
//  MarkAttendanceModels.swift
//  Truedata
//

import Foundation

enum AttendanceCheckInState {
    case checkIn
    case checkOut
    case done
}

struct AttendanceStatusResponse: Decodable {
    var status: Bool
    var message: String
    var data: AttendanceStatusData

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
        data = (try? container.decode(AttendanceStatusData.self, forKey: .data)) ?? AttendanceStatusData()
    }
}

struct AttendanceStatusData: Decodable {
    var inTime: String
    var outTime: String
    var inTimeStatus: Bool
    var outTimeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case inTime = "in_time"
        case outTime = "out_time"
        case inTimeStatus = "in_time_status"
        case outTimeStatus = "out_time_status"
    }

    init(
        inTime: String = "No data available",
        outTime: String = "No data available",
        inTimeStatus: Bool = false,
        outTimeStatus: Bool = false
    ) {
        self.inTime = inTime
        self.outTime = outTime
        self.inTimeStatus = inTimeStatus
        self.outTimeStatus = outTimeStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inTime = container.decodeStringLeniently(forKey: .inTime) ?? "No data available"
        outTime = container.decodeStringLeniently(forKey: .outTime) ?? "No data available"
        inTimeStatus = container.decodeBoolLeniently(forKey: .inTimeStatus) ?? false
        outTimeStatus = container.decodeBoolLeniently(forKey: .outTimeStatus) ?? false
    }
}

struct AttendanceListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [AttendanceHistoryItem]

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
        data = (try? container.decode([AttendanceHistoryItem].self, forKey: .data)) ?? []
    }
}

struct AttendanceHistoryItem: Identifiable, Decodable, Hashable {
    var id: Int
    var date: String
    var inTime: String
    var outTime: String?
    var inTimeAddress: String
    var outTimeAddress: String?
    var workingHours: String?

    enum CodingKeys: String, CodingKey {
        case id, date
        case inTime = "in_time"
        case outTime = "out_time"
        case inTimeAddress = "in_time_address"
        case outTimeAddress = "out_time_address"
        case workingHours = "working_hours"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        inTime = container.decodeStringLeniently(forKey: .inTime) ?? ""
        outTime = container.decodeStringLeniently(forKey: .outTime)
        inTimeAddress = container.decodeStringLeniently(forKey: .inTimeAddress) ?? ""
        outTimeAddress = container.decodeStringLeniently(forKey: .outTimeAddress)
        workingHours = container.decodeStringLeniently(forKey: .workingHours)
    }

    var formattedDate: String {
        AttendanceTimeFormatter.displayDate(from: date)
    }

    var formattedInTime: String {
        AttendanceTimeFormatter.displayTime(from: inTime)
    }

    var formattedOutTime: String {
        guard let outTime, !outTime.isEmpty else { return "--:-- --" }
        return AttendanceTimeFormatter.displayTime(from: outTime)
    }
}

struct MarkAttendanceResponse: Decodable {
    var status: Bool
    var message: String
    var data: MarkAttendanceResultData

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
        data = (try? container.decode(MarkAttendanceResultData.self, forKey: .data)) ?? MarkAttendanceResultData()
    }
}

struct MarkAttendanceResultData: Decodable {
    var date: String
    var inTime: String
    var outTime: String?

    enum CodingKeys: String, CodingKey {
        case date
        case inTime = "in_time"
        case outTime = "out_time"
    }

    init(date: String = "", inTime: String = "", outTime: String? = nil) {
        self.date = date
        self.inTime = inTime
        self.outTime = outTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        inTime = container.decodeStringLeniently(forKey: .inTime) ?? ""
        outTime = container.decodeStringLeniently(forKey: .outTime)
    }
}

enum AttendanceTimeFormatter {
    private static let inputTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let outputTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    private static let inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let outputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM, yyyy, EEEE"
        return formatter
    }()

    static func liveClockParts(from date: Date = Date()) -> (hour: String, minute: String, period: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        let parts = formatter.string(from: date).split(separator: " ")
        let timeParts = parts.first.map(String.init)?.split(separator: ":") ?? []
        return (
            hour: timeParts.first.map(String.init) ?? "00",
            minute: timeParts.dropFirst().first.map(String.init) ?? "00",
            period: parts.dropFirst().first.map(String.init) ?? "AM"
        )
    }

    static func headerDate(from date: Date = Date()) -> String {
        headerDateFormatter.string(from: date)
    }

    static func displayTime(from raw: String) -> String {
        guard !raw.isEmpty, raw != "No data available" else { return raw }
        if let parsed = inputTimeFormatter.date(from: raw) {
            return outputTimeFormatter.string(from: parsed).uppercased()
        }
        return raw
    }

    static func displayDate(from raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        if let parsed = inputDateFormatter.date(from: raw) {
            return outputDateFormatter.string(from: parsed)
        }
        return raw
    }
}
