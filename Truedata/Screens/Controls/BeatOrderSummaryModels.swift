//
//  BeatOrderSummaryModels.swift
//  Truedata
//

import Foundation
import SwiftUI

struct BeatOrderSummaryResponse: Decodable {
    var status: Bool
    var message: String
    var dateRange: BeatSummaryDateRange?
    var overallSummary: BeatOverallSummary?
    var beatWiseSummary: [BeatSummaryItem]

    enum CodingKeys: String, CodingKey {
        case status, message
        case dateRange = "date_range"
        case overallSummary = "overall_summary"
        case beatWiseSummary = "beat_wise_summary"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        dateRange = try? container.decode(BeatSummaryDateRange.self, forKey: .dateRange)
        overallSummary = try? container.decode(BeatOverallSummary.self, forKey: .overallSummary)
        beatWiseSummary = (try? container.decode([BeatSummaryItem].self, forKey: .beatWiseSummary)) ?? []
    }
}

struct BeatSummaryDateRange: Decodable, Hashable {
    var startDate: String
    var endDate: String

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = container.decodeStringLeniently(forKey: .startDate) ?? ""
        endDate = container.decodeStringLeniently(forKey: .endDate) ?? ""
    }
}

struct BeatOverallSummary: Decodable, Hashable {
    var totalBeats: Int
    var totalOrders: Int
    var totalPlacedOrders: Int
    var totalCancelledOrders: Int
    var totalDeliveredOrders: Int
    var totalOrderAmount: Double
    var outOfRangeOrders: Int
    var totalSettledAmount: Double

    enum CodingKeys: String, CodingKey {
        case totalBeats = "total_beats"
        case totalOrders = "total_orders"
        case totalPlacedOrders = "total_placed_orders"
        case totalCancelledOrders = "total_cancelled_orders"
        case totalDeliveredOrders = "total_delivered_orders"
        case totalOrderAmount = "total_order_amount"
        case outOfRangeOrders = "out_of_range_orders"
        case totalSettledAmount = "total_settled_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalBeats = container.decodeIntLeniently(forKey: .totalBeats) ?? 0
        totalOrders = container.decodeIntLeniently(forKey: .totalOrders) ?? 0
        totalPlacedOrders = container.decodeIntLeniently(forKey: .totalPlacedOrders) ?? 0
        totalCancelledOrders = container.decodeIntLeniently(forKey: .totalCancelledOrders) ?? 0
        totalDeliveredOrders = container.decodeIntLeniently(forKey: .totalDeliveredOrders) ?? 0
        totalOrderAmount = container.decodeDoubleLeniently(forKey: .totalOrderAmount) ?? 0
        outOfRangeOrders = container.decodeIntLeniently(forKey: .outOfRangeOrders) ?? 0
        totalSettledAmount = container.decodeDoubleLeniently(forKey: .totalSettledAmount) ?? 0
    }
}

struct BeatSummaryItem: Identifiable, Hashable, Decodable {
    var id: Int { beatId }
    var beatId: Int
    var beatName: String
    var activeBeatStaff: String
    var state: String
    var city: String
    var totalOrders: Int
    var placedOrders: BeatOrderCategoryDetail
    var cancelledOrders: BeatOrderCategoryDetail
    var deliveredOrders: BeatOrderCategoryDetail
    var staffWiseBreakdown: [BeatStaffBreakdownItem]

    enum CodingKeys: String, CodingKey {
        case beatId = "beat_id"
        case beatName = "beat_name"
        case activeBeatStaff = "active_beat_staff"
        case state, city
        case totalOrders = "total_orders"
        case placedOrders = "placed_orders"
        case cancelledOrders = "cancelled_orders"
        case deliveredOrders = "delivered_orders"
        case staffWiseBreakdown = "staff_wise_breakdown"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        beatId = container.decodeIntLeniently(forKey: .beatId) ?? 0
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        activeBeatStaff = container.decodeStringLeniently(forKey: .activeBeatStaff) ?? "Active Beat Staff : N/A"
        state = container.decodeStringLeniently(forKey: .state) ?? ""
        city = container.decodeStringLeniently(forKey: .city) ?? ""
        totalOrders = container.decodeIntLeniently(forKey: .totalOrders) ?? 0
        placedOrders = (try? container.decode(BeatOrderCategoryDetail.self, forKey: .placedOrders)) ?? BeatOrderCategoryDetail()
        cancelledOrders = (try? container.decode(BeatOrderCategoryDetail.self, forKey: .cancelledOrders)) ?? BeatOrderCategoryDetail()
        deliveredOrders = (try? container.decode(BeatOrderCategoryDetail.self, forKey: .deliveredOrders)) ?? BeatOrderCategoryDetail()
        staffWiseBreakdown = (try? container.decode([BeatStaffBreakdownItem].self, forKey: .staffWiseBreakdown)) ?? []
    }

    var locationText: String {
        [city, state].filter { !$0.isEmptyString }.joined(separator: ", ")
    }
}

struct BeatOrderCategoryDetail: Hashable, Decodable {
    var count: Int
    var orderIds: [String]
    var totalAmount: Double
    var totalCollectedAmount: Double

    enum CodingKeys: String, CodingKey {
        case count
        case orderIds = "order_ids"
        case totalAmount = "total_amount"
        case totalCollectedAmount = "total_collected_amount"
    }

    init(count: Int = 0, orderIds: [String] = [], totalAmount: Double = 0, totalCollectedAmount: Double = 0) {
        self.count = count
        self.orderIds = orderIds
        self.totalAmount = totalAmount
        self.totalCollectedAmount = totalCollectedAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeIntLeniently(forKey: .count) ?? 0
        orderIds = (try? container.decode([String].self, forKey: .orderIds)) ?? []
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
        totalCollectedAmount = container.decodeDoubleLeniently(forKey: .totalCollectedAmount) ?? 0
    }
}

struct BeatStaffBreakdownItem: Identifiable, Hashable, Decodable {
    var id: String { staffId }
    var staffId: String
    var staffName: String
    var totalOrders: Int
    var placedOrdersCount: Int
    var cancelledOrdersCount: Int
    var deliveredOrdersCount: Int
    var orderIds: [String]
    var totalAmount: Double

    enum CodingKeys: String, CodingKey {
        case staffId = "staff_id"
        case staffName = "staff_name"
        case totalOrders = "total_orders"
        case placedOrdersCount = "placed_orders"
        case cancelledOrdersCount = "cancelled_orders"
        case deliveredOrdersCount = "delivered_orders"
        case orderIds = "order_ids"
        case totalAmount = "total_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        totalOrders = container.decodeIntLeniently(forKey: .totalOrders) ?? 0
        placedOrdersCount = container.decodeIntLeniently(forKey: .placedOrdersCount) ?? 0
        cancelledOrdersCount = container.decodeIntLeniently(forKey: .cancelledOrdersCount) ?? 0
        deliveredOrdersCount = container.decodeIntLeniently(forKey: .deliveredOrdersCount) ?? 0
        orderIds = (try? container.decode([String].self, forKey: .orderIds)) ?? []
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
    }
}

struct BeatSummaryBeatOption: Identifiable, Hashable {
    var id: String
    var displayName: String
}

struct BeatSummaryFilters: Equatable {
    var startDate: String
    var endDate: String
    var datePreset: AchievementHistoryDatePreset
    var beatId: String
    var beatName: String
    var staffId: String
    var staffName: String

    var activeFilterCount: Int {
        (beatId.isEmpty ? 0 : 1) + (staffId.isEmpty ? 0 : 1)
    }

    static func initialToday() -> BeatSummaryFilters {
        let today = OrderInsightsDateFormat.string(from: Date())
        return BeatSummaryFilters(
            startDate: today,
            endDate: today,
            datePreset: .today,
            beatId: "",
            beatName: "",
            staffId: "",
            staffName: ""
        )
    }
}

struct BeatSummaryOrderListContext: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let orderIds: [String]
}

enum BeatSummaryOrderIDParser {
    static func normalizedOrderId(_ value: String) -> String {
        if let match = value.range(of: #"#?\d+"#, options: .regularExpression) {
            return String(value[match]).replacingOccurrences(of: "#", with: "")
        }
        return value.replacingOccurrences(of: "#", with: "")
    }
}
