//
//  SellerReportModels.swift
//  Truedata
//

import Foundation

struct SellerReportItem: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String
    var beatName: String
    var registeredBy: String
    var registeredByName: String
    var status: String
    var profilePic: String
    var createdAt: String
    var registrationDate: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status
        case shopName = "shop_name"
        case beatName = "beat_name"
        case registeredBy = "registered_by"
        case registeredByName = "registered_by_name"
        case profilePic = "profile_pic"
        case createdAt = "created_at"
        case registrationDate = "registration_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? "N/A"
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? "Unknown"
        registeredBy = container.decodeStringLeniently(forKey: .registeredBy) ?? "Unknown"
        registeredByName = container.decodeStringLeniently(forKey: .registeredByName) ?? "Unknown"
        status = container.decodeStringLeniently(forKey: .status) ?? "Unknown"
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
        registrationDate = container.decodeStringLeniently(forKey: .registrationDate) ?? ""
    }

    var displayShopName: String {
        shopName.isEmptyString ? name : shopName
    }

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame || status == "1"
    }

    var statusLabel: String {
        if status == "1" { return "Active" }
        if status.isEmptyString || status == "Unknown" { return "Unknown" }
        return status.prefix(1).uppercased() + status.dropFirst().lowercased()
    }

    var registeredOnText: String {
        SellerReportDateFormat.registrationDisplay(
            from: registrationDate.isEmptyString ? createdAt : registrationDate
        )
    }
}

struct SellerReportListResponse: Decodable {
    var status: Bool
    var message: String
    var data: SellerReportPage

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(SellerReportPage.self, forKey: .data)) ?? SellerReportPage()
    }
}

struct SellerReportPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var sellers: [SellerReportItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case sellers
    }

    init(currentPage: Int = 0, lastPage: Int = 0, total: Int = 0, sellers: [SellerReportItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.sellers = sellers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        sellers = (try? container.decode([SellerReportItem].self, forKey: .sellers)) ?? []
    }

    var hasNextPage: Bool { currentPage < lastPage }
}

struct SellerReportFilters: Equatable {
    var startDate: String
    var endDate: String
    var datePreset: AchievementHistoryDatePreset
    var staffId: String
    var staffName: String
    var beatId: String
    var beatName: String

    static func initialToday() -> SellerReportFilters {
        let today = OrderInsightsDateFormat.todayString
        return SellerReportFilters(
            startDate: today,
            endDate: today,
            datePreset: .today,
            staffId: "",
            staffName: "",
            beatId: "",
            beatName: ""
        )
    }

    var hasActiveFilters: Bool {
        !staffId.isEmpty || !beatId.isEmpty || datePreset != .today
    }
}

enum SellerReportDateFormat {
    static func registrationDisplay(from raw: String) -> String {
        guard !raw.isEmptyString else { return "Unknown" }

        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"

        guard let date = input.date(from: raw) else { return raw }

        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM"
        let month = monthFormatter.string(from: date)
        let year = calendar.component(.year, from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "h:mm a"
        let time = timeFormatter.string(from: date).lowercased()

        return "\(day)\(suffix) \(month), \(year) at \(time)"
    }
}
