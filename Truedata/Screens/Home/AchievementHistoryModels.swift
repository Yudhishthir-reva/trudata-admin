//
//  AchievementHistoryModels.swift
//  Truedata
//

import Foundation

enum AchievementHistoryViewMode: String, CaseIterable {
    case report
    case list

    var title: String {
        switch self {
        case .report: return "Report"
        case .list: return "List"
        }
    }
}

enum AchievementHistoryDatePreset: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case thisFinancialYear = "This Financial Year"
    case lastFinancialYear = "Last Financial Year"
    case custom = "Custom"

    var id: String { rawValue }

    static var selectablePresets: [AchievementHistoryDatePreset] {
        allCases.filter { $0 != .custom }
    }

    static func dateRange(for preset: AchievementHistoryDatePreset) -> (start: String, end: String)? {
        let calendar = Calendar.current
        let today = Date()
        let formatter = OrderInsightsDateFormat.self

        switch preset {
        case .today:
            return (formatter.string(from: today), formatter.string(from: today))
        case .yesterday:
            guard let date = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
            let value = formatter.string(from: date)
            return (value, value)
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return nil }
            return (formatter.string(from: monday), formatter.string(from: today))
        case .lastWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
                  let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday),
                  let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday) else { return nil }
            return (formatter.string(from: lastMonday), formatter.string(from: lastSunday))
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: today)
            guard let start = calendar.date(from: comps) else { return nil }
            return (formatter.string(from: start), formatter.string(from: today))
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: today) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: lastMonth)
            guard let start = calendar.date(from: comps),
                  let range = calendar.range(of: .day, in: .month, for: lastMonth),
                  let end = calendar.date(byAdding: .day, value: range.count - 1, to: start) else { return nil }
            return (formatter.string(from: start), formatter.string(from: end))
        case .thisYear:
            let year = calendar.component(.year, from: today)
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
            return (formatter.string(from: start), formatter.string(from: today))
        case .thisFinancialYear:
            return financialYearRange(offsetYears: 0, calendar: calendar, today: today, formatter: formatter)
        case .lastFinancialYear:
            return financialYearRange(offsetYears: -1, calendar: calendar, today: today, formatter: formatter)
        case .custom:
            return nil
        }
    }

    private static func financialYearRange(
        offsetYears: Int,
        calendar: Calendar,
        today: Date,
        formatter: OrderInsightsDateFormat.Type
    ) -> (start: String, end: String)? {
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        let baseYear = month >= 4 ? year + offsetYears : year - 1 + offsetYears
        guard let start = calendar.date(from: DateComponents(year: baseYear, month: 4, day: 1)),
              let end = calendar.date(from: DateComponents(year: baseYear + 1, month: 3, day: 31)) else {
            return nil
        }
        return (formatter.string(from: start), formatter.string(from: end))
    }
}

struct AchievementSellerOrderRow: Identifiable, Hashable {
    let id: String
    let sellerName: String
    let orderCount: Int
}

struct AchievementSellerCollectionRow: Identifiable, Hashable {
    let id: String
    let sellerName: String
    let totalAmount: Double
}

struct AchievementPaymentModeStat: Identifiable, Hashable {
    let id: String
    let sellerId: String
    let sellerName: String
    let paymentModeId: Int
    let transactionCount: Int
    let totalAmount: Double

    func modeLabel(from map: [Int: String]) -> String {
        let label = map[paymentModeId] ?? paymentModeLabel(for: paymentModeId)
        return label.isEmptyString ? paymentModeLabel(for: paymentModeId) : label.capitalized
    }

    private func paymentModeLabel(for modeId: Int) -> String {
        switch modeId {
        case 1: return "Cash"
        case 2: return "UPI"
        case 3: return "Cheque"
        default: return "Other"
        }
    }
}

struct AchievementPaymentModeSummary: Identifiable, Hashable {
    let id: Int
    let label: String
    let amount: Double
}

struct AchievementSellerPaymentGroup: Identifiable, Hashable {
    let id: String
    let sellerName: String
    let stats: [AchievementPaymentModeStat]
}

struct AchievementHistoryData {
    let summary: TodayAchievementsSummary
    let sellerOrders: [AchievementSellerOrderRow]
    let sellerCollections: [AchievementSellerCollectionRow]
    let paymentModeStats: [AchievementPaymentModeStat]
    let paymentModeMap: [Int: String]

    static let empty = AchievementHistoryData(
        summary: .empty,
        sellerOrders: [],
        sellerCollections: [],
        paymentModeStats: [],
        paymentModeMap: [:]
    )

    var isEmpty: Bool {
        sellerOrders.isEmpty
            && sellerCollections.isEmpty
            && paymentModeStats.isEmpty
            && summary.totalTransactions == 0
            && summary.sellerCount == 0
    }

    var sortedSellerOrders: [AchievementSellerOrderRow] {
        sellerOrders.sorted { $0.orderCount > $1.orderCount }
    }

    var sortedSellerCollections: [AchievementSellerCollectionRow] {
        sellerCollections.sorted { $0.totalAmount > $1.totalAmount }
    }

    var paymentModeSummaries: [AchievementPaymentModeSummary] {
        let grouped = Dictionary(grouping: paymentModeStats, by: \.paymentModeId)
        return grouped.map { modeId, stats in
            AchievementPaymentModeSummary(
                id: modeId,
                label: stats.first?.modeLabel(from: paymentModeMap) ?? "Other",
                amount: stats.reduce(0) { $0 + $1.totalAmount }
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    var sellerPaymentGroups: [AchievementSellerPaymentGroup] {
        let grouped = Dictionary(grouping: paymentModeStats, by: \.sellerName)
        return grouped.map { sellerName, stats in
            AchievementSellerPaymentGroup(
                id: stats.first?.sellerId ?? sellerName,
                sellerName: sellerName,
                stats: stats.sorted { $0.totalAmount > $1.totalAmount }
            )
        }
        .sorted { lhs, rhs in
            lhs.stats.reduce(0) { $0 + $1.totalAmount } > rhs.stats.reduce(0) { $0 + $1.totalAmount }
        }
    }
}

struct AchievementHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var rawData: JSONValue?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           container.contains(.data) || container.contains(.status) {
            status = container.decodeBoolLeniently(forKey: .status) ?? true
            if let list = try? container.decode([String].self, forKey: .message) {
                message = list.joined(separator: "\n")
            } else {
                message = container.decodeStringLeniently(forKey: .message) ?? ""
            }
            rawData = try? container.decode(JSONValue.self, forKey: .data)
        } else {
            status = true
            message = ""
            rawData = try JSONValue(from: decoder)
        }
    }

    var parsedData: AchievementHistoryData {
        guard let rawData else {
            return AchievementHistoryData.from(root: .object([:]))
        }
        return AchievementHistoryData.from(root: rawData)
    }
}

extension AchievementHistoryData {
    static func from(root: JSONValue) -> AchievementHistoryData {
        let payload = root.objectValue

        if case .array = payload["todaySellerCount"] ?? .null {
            return fromDetailsPayload(payload)
        }
        if case .array = payload["paymentModeWise"] ?? .null {
            return fromDetailsPayload(payload)
        }

        if payload["todaySellerCount"] != nil || payload["paymentModeWise"] != nil {
            return AchievementHistoryData(
                summary: TodayAchievementsSummary.from(dictionary: payload),
                sellerOrders: [],
                sellerCollections: [],
                paymentModeStats: [],
                paymentModeMap: parsePaymentModeMap(payload["statusMap"])
            )
        }

        return .empty
    }

    private static func fromDetailsPayload(_ payload: [String: JSONValue]) -> AchievementHistoryData {
        let sellerOrders = parseSellerOrders(payload["todaySellerCount"])
        let sellerCollections = parseSellerCollections(payload["todayCollectionAmount"])
        let paymentModeStats = parsePaymentModeStats(payload["paymentModeWise"])
        let paymentModeMap = parsePaymentModeMap(payload["statusMap"])

        var cashCount = 0
        var upiCount = 0
        var chequeCount = 0
        var cashAmount = 0.0
        var upiAmount = 0.0
        var chequeAmount = 0.0

        for stat in paymentModeStats {
            switch stat.modeLabel(from: paymentModeMap).lowercased() {
            case "cash":
                cashCount += stat.transactionCount
                cashAmount += stat.totalAmount
            case "upi":
                upiCount += stat.transactionCount
                upiAmount += stat.totalAmount
            case "cheque":
                chequeCount += stat.transactionCount
                chequeAmount += stat.totalAmount
            default:
                break
            }
        }

        let totalCollection = sellerCollections.reduce(0) { $0 + $1.totalAmount }

        let summary = TodayAchievementsSummary(
            sellerCount: sellerOrders.count,
            collectionAmount: totalCollection,
            approvedAmount: totalCollection,
            cashCount: cashCount,
            upiCount: upiCount,
            chequeCount: chequeCount,
            cashAmount: cashAmount,
            upiAmount: upiAmount,
            chequeAmount: chequeAmount
        )

        return AchievementHistoryData(
            summary: summary,
            sellerOrders: sellerOrders,
            sellerCollections: sellerCollections,
            paymentModeStats: paymentModeStats,
            paymentModeMap: paymentModeMap
        )
    }

    private static func parseSellerOrders(_ value: JSONValue?) -> [AchievementSellerOrderRow] {
        guard let items = value?.arrayValue else { return [] }
        return items.compactMap { item in
            let object = JSONValue.object(item.objectValue)
            let sellerId = object.string(for: "seller_id", "sellerId")
            let sellerName = object.string(for: "seller_name", "sellerName")
            let orderCount = object.int(for: "order_count", "orderCount")
            guard !sellerId.isEmptyString || !sellerName.isEmptyString else { return nil }
            return AchievementSellerOrderRow(
                id: sellerId.isEmptyString ? sellerName : sellerId,
                sellerName: sellerName.isEmptyString ? "Seller" : sellerName,
                orderCount: orderCount
            )
        }
    }

    private static func parseSellerCollections(_ value: JSONValue?) -> [AchievementSellerCollectionRow] {
        guard let items = value?.arrayValue else { return [] }
        return items.compactMap { item in
            let object = JSONValue.object(item.objectValue)
            let sellerId = object.string(for: "seller_id", "sellerId")
            let sellerName = object.string(for: "seller_name", "sellerName")
            let total = object.double(for: "total", "totalAmount")
            guard !sellerId.isEmptyString || !sellerName.isEmptyString else { return nil }
            return AchievementSellerCollectionRow(
                id: sellerId.isEmptyString ? sellerName : sellerId,
                sellerName: sellerName.isEmptyString ? "Seller" : sellerName,
                totalAmount: total
            )
        }
    }

    private static func parsePaymentModeStats(_ value: JSONValue?) -> [AchievementPaymentModeStat] {
        guard let items = value?.arrayValue else { return [] }
        return items.compactMap { item in
            let object = JSONValue.object(item.objectValue)
            let sellerId = object.string(for: "seller_id", "sellerId")
            let sellerName = object.string(for: "seller_name", "sellerName")
            let modeId = object.int(for: "payment_mode", "paymentMode")
            let count = object.int(for: "count")
            let amount = object.double(for: "total", "totalAmount")
            guard !sellerId.isEmptyString || !sellerName.isEmptyString else { return nil }
            let rowId = "\(sellerId)-\(modeId)-\(sellerName)"
            return AchievementPaymentModeStat(
                id: rowId,
                sellerId: sellerId,
                sellerName: sellerName.isEmptyString ? "Seller" : sellerName,
                paymentModeId: modeId,
                transactionCount: count,
                totalAmount: amount
            )
        }
    }

    private static func parsePaymentModeMap(_ value: JSONValue?) -> [Int: String] {
        guard let items = value?.arrayValue else { return [:] }
        var map: [Int: String] = [:]
        for item in items {
            let object = JSONValue.object(item.objectValue)
            let key = object.int(for: "key")
            let label = object.string(for: "label")
            if key > 0, !label.isEmptyString {
                map[key] = label
            }
        }
        return map
    }
}
