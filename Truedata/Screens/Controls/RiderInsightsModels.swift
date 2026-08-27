//
//  RiderInsightsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

// MARK: - Enums

enum RiderViewMode: String, CaseIterable, Identifiable {
    case insights = "Insights"
    case reports = "Rider Reports"
    case assigned = "Assigned"
    case pickedUp = "Picked Up"
    case active = "Active"
    case delivered = "Delivered"

    var id: String { rawValue }
    var title: String { rawValue }
}

enum RiderDatePreset: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"

    var id: String { rawValue }

    var dateRange: (start: String, end: String) {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch self {
        case .today:
            let dateStr = formatter.string(from: now)
            return (dateStr, dateStr)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let dateStr = formatter.string(from: yesterday)
            return (dateStr, dateStr)
        case .thisWeek:
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                let dateStr = formatter.string(from: now)
                return (dateStr, dateStr)
            }
            return (formatter.string(from: startOfWeek), formatter.string(from: now))
        case .lastWeek:
            guard let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                  let startOfLastWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeekDate)),
                  let endOfLastWeek = calendar.date(byAdding: .day, value: 6, to: startOfLastWeek) else {
                let dateStr = formatter.string(from: now)
                return (dateStr, dateStr)
            }
            return (formatter.string(from: startOfLastWeek), formatter.string(from: endOfLastWeek))
        case .thisMonth:
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                let dateStr = formatter.string(from: now)
                return (dateStr, dateStr)
            }
            return (formatter.string(from: startOfMonth), formatter.string(from: now))
        case .lastMonth:
            guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now),
                  let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate)),
                  let range = calendar.range(of: .day, in: .month, for: lastMonthDate),
                  let endOfLastMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfLastMonth) else {
                let dateStr = formatter.string(from: now)
                return (dateStr, dateStr)
            }
            return (formatter.string(from: startOfLastMonth), formatter.string(from: endOfLastMonth))
        }
    }
}

// MARK: - API Response Models

struct RiderActivityDashboardResponse: Decodable {
    var status: Bool
    var message: String
    var data: RiderActivityDashboardPayload?

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
        data = try? container.decode(RiderActivityDashboardPayload.self, forKey: .data)
    }
}

struct RiderActivityDashboardPayload: Decodable {
    var deliveredOrders: HistorySection<DeliveredRiderOrderDto>
    var allRiders: HistorySection<AllRidersOrderDto>
    var assignedRiders: HistorySection<AssignedRiderOrderDto>
    var pickedUpRiders: HistorySection<PickedUpRiderOrderDto>
    var activeRiders: HistorySection<ActiveRiderOrderDto>
    var topRiders: HistorySection<TopRiderDto>
    var orderStatusMap: [OrderStatusMapItemDto]

    enum CodingKeys: String, CodingKey {
        case deliveredOrders = "delivered_orders"
        case allRiders = "all_riders"
        case assignedRiders = "assigned_riders"
        case pickedUpRiders = "pickedup_riders"
        case activeRiders = "active_riders"
        case topRiders = "top_riders"
        case orderStatusMap
    }

    init(
        deliveredOrders: HistorySection<DeliveredRiderOrderDto> = HistorySection(),
        allRiders: HistorySection<AllRidersOrderDto> = HistorySection(),
        assignedRiders: HistorySection<AssignedRiderOrderDto> = HistorySection(),
        pickedUpRiders: HistorySection<PickedUpRiderOrderDto> = HistorySection(),
        activeRiders: HistorySection<ActiveRiderOrderDto> = HistorySection(),
        topRiders: HistorySection<TopRiderDto> = HistorySection(),
        orderStatusMap: [OrderStatusMapItemDto] = []
    ) {
        self.deliveredOrders = deliveredOrders
        self.allRiders = allRiders
        self.assignedRiders = assignedRiders
        self.pickedUpRiders = pickedUpRiders
        self.activeRiders = activeRiders
        self.topRiders = topRiders
        self.orderStatusMap = orderStatusMap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deliveredOrders = (try? container.decode(HistorySection<DeliveredRiderOrderDto>.self, forKey: .deliveredOrders)) ?? HistorySection()
        allRiders = (try? container.decode(HistorySection<AllRidersOrderDto>.self, forKey: .allRiders)) ?? HistorySection()
        assignedRiders = (try? container.decode(HistorySection<AssignedRiderOrderDto>.self, forKey: .assignedRiders)) ?? HistorySection()
        pickedUpRiders = (try? container.decode(HistorySection<PickedUpRiderOrderDto>.self, forKey: .pickedUpRiders)) ?? HistorySection()
        activeRiders = (try? container.decode(HistorySection<ActiveRiderOrderDto>.self, forKey: .activeRiders)) ?? HistorySection()
        topRiders = (try? container.decode(HistorySection<TopRiderDto>.self, forKey: .topRiders)) ?? HistorySection()
        orderStatusMap = (try? container.decode([OrderStatusMapItemDto].self, forKey: .orderStatusMap)) ?? []
    }
}

struct HistorySection<T: Decodable>: Decodable {
    var count: Int
    var history: [T]

    enum CodingKeys: String, CodingKey {
        case count, history
    }

    init(count: Int = 0, history: [T] = []) {
        self.count = count
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeIntLeniently(forKey: .count) ?? 0
        history = (try? container.decode([T].self, forKey: .history)) ?? []
    }
}

struct DeliveredRiderOrderDto: Decodable {
    var orderId: String
    var deliveryDate: String?
    var totalPrice: String
    var discount: String
    var rider: RiderInfoDto?
    var seller: SellerInfoDto?
    var staff: StaffInfoDto?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case deliveryDate = "delivery_date"
        case totalPrice = "total_price"
        case discount, rider, seller, staff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate)
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        discount = container.decodeStringLeniently(forKey: .discount) ?? "0.00"
        rider = try? container.decode(RiderInfoDto.self, forKey: .rider)
        seller = try? container.decode(SellerInfoDto.self, forKey: .seller)
        staff = try? container.decode(StaffInfoDto.self, forKey: .staff)
    }
}

struct AllRidersOrderDto: Decodable {
    var orderId: String
    var orderStatus: String
    var totalPrice: String
    var rider: RiderInfoDto?
    var seller: SellerInfoSimpleDto?
    var staff: StaffInfoDto?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case totalPrice = "total_price"
        case rider, seller, staff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? "0"
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        rider = try? container.decode(RiderInfoDto.self, forKey: .rider)
        seller = try? container.decode(SellerInfoSimpleDto.self, forKey: .seller)
        staff = try? container.decode(StaffInfoDto.self, forKey: .staff)
    }
}

struct AssignedRiderOrderDto: Decodable {
    var orderId: String
    var orderStatus: String
    var shopName: String?
    var salePersonName: String?
    var riderName: String?
    var totalPrice: String
    var currentLat: String
    var currentLng: String
    var riderCurrentAddress: String
    var totalDistance: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case shopName = "shop_name"
        case salePersonName = "sale_person_name"
        case riderName = "rider_name"
        case totalPrice = "total_price"
        case currentLat = "current_lat"
        case currentLng = "current_lng"
        case riderCurrentAddress = "rider_current_address"
        case totalDistance = "total_distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? "0"
        shopName = container.decodeStringLeniently(forKey: .shopName)
        salePersonName = container.decodeStringLeniently(forKey: .salePersonName)
        riderName = container.decodeStringLeniently(forKey: .riderName)
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        currentLat = container.decodeStringLeniently(forKey: .currentLat) ?? "0"
        currentLng = container.decodeStringLeniently(forKey: .currentLng) ?? "0"
        riderCurrentAddress = container.decodeStringLeniently(forKey: .riderCurrentAddress) ?? ""
        totalDistance = container.decodeStringLeniently(forKey: .totalDistance) ?? "0"
    }
}

struct PickedUpRiderOrderDto: Decodable {
    var orderId: String
    var orderStatus: String
    var shopName: String?
    var salePersonName: String?
    var riderName: String?
    var totalPrice: String
    var currentLat: String
    var currentLng: String
    var riderCurrentAddress: String
    var totalDistance: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case shopName = "shop_name"
        case salePersonName = "sale_person_name"
        case riderName = "rider_name"
        case totalPrice = "total_price"
        case currentLat = "current_lat"
        case currentLng = "current_lng"
        case riderCurrentAddress = "rider_current_address"
        case totalDistance = "total_distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? "0"
        shopName = container.decodeStringLeniently(forKey: .shopName)
        salePersonName = container.decodeStringLeniently(forKey: .salePersonName)
        riderName = container.decodeStringLeniently(forKey: .riderName)
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        currentLat = container.decodeStringLeniently(forKey: .currentLat) ?? "0"
        currentLng = container.decodeStringLeniently(forKey: .currentLng) ?? "0"
        riderCurrentAddress = container.decodeStringLeniently(forKey: .riderCurrentAddress) ?? ""
        totalDistance = container.decodeStringLeniently(forKey: .totalDistance) ?? "0"
    }
}

struct ActiveRiderOrderDto: Decodable {
    var orderId: String
    var orderStatus: String
    var shopName: String?
    var salePersonName: String?
    var riderName: String?
    var totalPrice: String
    var currentLat: String
    var currentLng: String
    var riderCurrentAddress: String
    var totalDistance: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case shopName = "shop_name"
        case salePersonName = "sale_person_name"
        case riderName = "rider_name"
        case totalPrice = "total_price"
        case currentLat = "current_lat"
        case currentLng = "current_lng"
        case riderCurrentAddress = "rider_current_address"
        case totalDistance = "total_distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? "0"
        shopName = container.decodeStringLeniently(forKey: .shopName)
        salePersonName = container.decodeStringLeniently(forKey: .salePersonName)
        riderName = container.decodeStringLeniently(forKey: .riderName)
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        currentLat = container.decodeStringLeniently(forKey: .currentLat) ?? "0"
        currentLng = container.decodeStringLeniently(forKey: .currentLng) ?? "0"
        riderCurrentAddress = container.decodeStringLeniently(forKey: .riderCurrentAddress) ?? ""
        totalDistance = container.decodeStringLeniently(forKey: .totalDistance) ?? "0"
    }
}

struct TopRiderDto: Decodable {
    var riderId: String
    var riderName: String
    var riderNumber: String?
    var totalDelivered: String

    enum CodingKeys: String, CodingKey {
        case riderId = "order_rider_id"
        case riderName = "rider_name"
        case riderNumber = "rider_number"
        case totalDelivered = "total_delivered"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        riderId = container.decodeStringLeniently(forKey: .riderId) ?? ""
        riderName = container.decodeStringLeniently(forKey: .riderName) ?? ""
        riderNumber = container.decodeStringLeniently(forKey: .riderNumber)
        totalDelivered = container.decodeStringLeniently(forKey: .totalDelivered) ?? "0"
    }
}

struct RiderInfoDto: Decodable {
    var id: Int
    var name: String
    var mobile: String?

    enum CodingKeys: String, CodingKey {
        case id, name, mobile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile)
    }
}

struct SellerInfoDto: Decodable {
    var id: Int
    var name: String
    var shopName: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case shopName = "shop_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
    }
}

struct SellerInfoSimpleDto: Decodable {
    var id: Int
    var shopName: String

    enum CodingKeys: String, CodingKey {
        case id
        case shopName = "shop_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
    }
}

struct StaffInfoDto: Decodable {
    var id: Int
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct OrderStatusMapItemDto: Decodable {
    var key: Int
    var label: String

    enum CodingKeys: String, CodingKey {
        case key, label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeIntLeniently(forKey: .key) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? ""
    }
}

// MARK: - Domain / View Presentation Models

struct RiderOrderDisplayItem: Identifiable, Hashable {
    var id: String { orderId }
    var orderId: String
    var totalPrice: Double
    var orderStatusKey: Int
    var orderStatusLabel: String
    var riderName: String
    var sellerName: String
    var staffName: String
    var distance: String?
    var address: String?
    var latitude: String?
    var longitude: String?

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalPrice)) ?? "₹\(String(format: "%.2f", totalPrice))"
    }

    var hasLocationCoordinates: Bool {
        guard let latStr = latitude, let lngStr = longitude,
              let lat = Double(latStr), let lng = Double(lngStr) else { return false }
        return lat != 0 && lng != 0
    }

    var statusBadgeColor: Color {
        switch orderStatusLabel.lowercased() {
        case "delivered":
            return DashboardTheme.successGreen
        case "pending":
            return DashboardTheme.warningYellow
        case "to deliver", "assign", "assigned":
            return DashboardTheme.primaryBlue
        case "pickup", "picked up":
            return Color(hex: "FD7E14")
        case "cancel", "cancelled":
            return DashboardTheme.dangerRed
        case "return", "returned":
            return Color(hex: "7C3AED")
        default:
            return DashboardTheme.neutralMedium
        }
    }
}

struct TopRiderItem: Identifiable, Hashable {
    var id: String { riderId }
    var riderId: String
    var name: String
    var totalDelivered: Int
}

struct RiderSummaryItem: Identifiable, Hashable {
    var id: String { riderName }
    var riderName: String
    var totalOrders: Int
}

struct RiderProfileItem: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var totalOrders: Int
    var deliveredCount: Int
    var totalAmount: Double
    var orders: [RiderOrderDisplayItem]
    var lastKnownAddress: String?
    var lastKnownLatitude: String?
    var lastKnownLongitude: String?

    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "₹\(String(format: "%.2f", totalAmount))"
    }

    var hasMapLocation: Bool {
        guard let latStr = lastKnownLatitude, let lngStr = lastKnownLongitude,
              let lat = Double(latStr), let lng = Double(lngStr) else { return false }
        return lat != 0 && lng != 0
    }
}
