//
//  FailedOrdersModels.swift
//  Truedata
//

import Foundation

enum FailedOrdersFilterCategory: String, CaseIterable {
    case dateRange = "Date Range"
    case rider = "Rider"
    case seller = "Seller"
}

struct FailedOrdersAppliedFilters: Equatable {
    var startDate: String
    var endDate: String
    var datePreset: AchievementHistoryDatePreset
    var sellerId: String
    var riderId: String
}

struct FailedOrdersResponse: Decodable {
    var status: Bool
    var message: String
    var data: [FailedOrderItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([FailedOrderItem].self, forKey: .data)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
}

struct FailedOrderItem: Identifiable, Hashable, Decodable {
    var id: Int
    var orderId: String
    var riderId: String?
    var sellerId: String?
    var dateTime: String
    var remark: String
    var status: String
    var order: FailedOrderDetails?
    var rider: FailedOrderRider?
    var seller: FailedOrderSeller?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case riderId = "rider_id"
        case sellerId = "seller_id"
        case dateTime = "date_time"
        case remark, status, order, rider, seller
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        riderId = container.decodeStringLeniently(forKey: .riderId)
        sellerId = container.decodeStringLeniently(forKey: .sellerId)
        dateTime = container.decodeStringLeniently(forKey: .dateTime) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        order = try? container.decode(FailedOrderDetails.self, forKey: .order)
        rider = try? container.decode(FailedOrderRider.self, forKey: .rider)
        seller = try? container.decode(FailedOrderSeller.self, forKey: .seller)
    }

    var displayOrderNo: String {
        let value = order?.orderNo.nilIfEmpty ?? orderId
        if value.hasPrefix("#") { return value }
        return "#\(value)"
    }

    var displayDate: String {
        if let orderDate = order?.orderDate.nilIfEmpty {
            return OrderInsightsDateFormat.normalizedAPIString(from: orderDate)
        }
        return dateTime.split(separator: " ").first.map(String.init) ?? dateTime
    }

    var totalAmount: String {
        order?.totalPrice.nilIfEmpty ?? "0.00"
    }

    var resolvedSellerName: String {
        if let shop = seller?.shopName.nilIfEmpty { return shop }
        if let name = seller?.name.nilIfEmpty { return name }
        return "Unknown Seller"
    }

    var resolvedSellerPhone: String {
        seller?.mobile.nilIfEmpty ?? "N/A"
    }

    var resolvedRiderName: String? {
        rider?.name.nilIfEmpty
    }

    var failureReason: String? {
        remark.nilIfEmpty
    }
}

struct FailedOrderDetails: Hashable, Decodable {
    var id: Int
    var orderNo: String
    var totalPrice: String
    var orderDate: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case orderNo = "order_no"
        case totalPrice = "total_price"
        case orderDate = "order_date"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0.00"
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
    }
}

struct FailedOrderRider: Hashable, Decodable {
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

struct FailedOrderSeller: Hashable, Decodable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile
        case shopName = "shop_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
    }
}
