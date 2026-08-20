//
//  StaffReportModels.swift
//  Truedata
//

import Foundation

struct StaffProfileContext: Hashable {
    var memberId: Int
    var displayStaffId: String
    var name: String
    var role: String
    var profilePic: String

    init(member: SalesmanStaffMember) {
        memberId = member.id
        displayStaffId = member.resolvedStaffId
        name = member.name
        role = member.roleId
        profilePic = member.profilePic
    }
}

enum StaffProfileTab: String, CaseIterable, Identifiable {
    case attendance = "Attendance"
    case location = "Location"

    var id: String { rawValue }
}

struct TeamAttendanceListResponse: Decodable {
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

struct StaffLocationLogItem: Identifiable, Hashable, Decodable {
    var id: Int
    var address: String
    var batteryLevel: String
    var latitude: String
    var longitude: String
    var createdDateTime: String
    var accuracyStatus: String?

    enum CodingKeys: String, CodingKey {
        case id, address, latitude, longitude
        case batteryLevel = "battery_level"
        case createdDateTime = "created_date_time"
        case accuracyStatus = "accuracy_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        batteryLevel = container.decodeStringLeniently(forKey: .batteryLevel) ?? ""
        latitude = container.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = container.decodeStringLeniently(forKey: .longitude) ?? ""
        createdDateTime = container.decodeStringLeniently(forKey: .createdDateTime) ?? ""
        accuracyStatus = container.decodeStringLeniently(forKey: .accuracyStatus)
    }

    var coordinateLabel: String {
        guard let lat = Double(latitude), let lng = Double(longitude) else { return "N/A" }
        return String(format: "%.4f, %.4f", lat, lng)
    }

    var hasMapCoordinates: Bool {
        guard let lat = Double(latitude), let lng = Double(longitude) else { return false }
        return lat != 0 && lng != 0
    }
}

struct StaffLocationListPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var data: [StaffLocationLogItem]

    enum CodingKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        data = (try? container.decode([StaffLocationLogItem].self, forKey: .data)) ?? []
    }
}

struct StaffLocationListResponse: Decodable {
    var status: Bool
    var message: String
    var data: StaffLocationListPage

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
        data = (try? container.decode(StaffLocationListPage.self, forKey: .data)) ?? StaffLocationListPage(currentPage: 1, lastPage: 1, data: [])
    }
}

private extension StaffLocationListPage {
    init(currentPage: Int, lastPage: Int, data: [StaffLocationLogItem]) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.data = data
    }
}

enum StaffProfileDateFormat {
    static var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    static var currentDate: String {
        AttendanceAPIDateFormat.string(from: Date())
    }
}
