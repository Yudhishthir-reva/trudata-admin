//
//  SalesmanActivitiesModels.swift
//  Truedata
//

import Foundation

struct SalesmanStaffListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [SalesmanStaffMember]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let text = try? container.decode(String.self, forKey: .message) {
            message = text
        } else if let messages = try? container.decode([String].self, forKey: .message) {
            message = messages.joined(separator: ", ")
        } else {
            message = ""
        }
        data = (try? container.decode([SalesmanStaffMember].self, forKey: .data)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
}

struct SalesmanStaffMember: Identifiable, Hashable, Decodable {
    var id: Int
    var staffId: String
    var name: String
    var mobile: String
    var roleId: String
    var profilePic: String
    var status: String
    var attendanceStatus: Int

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status
        case staffId = "staff_id"
        case roleId = "role_id"
        case profilePic = "profile_pic"
        case attendanceStatus = "attendance_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        roleId = container.decodeStringLeniently(forKey: .roleId) ?? ""
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        attendanceStatus = container.decodeIntLeniently(forKey: .attendanceStatus) ?? 0
    }

    var resolvedStaffId: String {
        if !staffId.isEmptyString { return staffId }
        return String(id)
    }

    var isPresent: Bool {
        attendanceStatus == 1
    }

    var attendanceLabel: String {
        isPresent ? "Present" : "Absent"
    }

    var isSalesmanEligible: Bool {
        roleId.caseInsensitiveCompare("Rider") != .orderedSame && status != "0"
    }
}

enum SalesmanActivityTab: String, CaseIterable, Identifiable {
    case summary
    case visits
    case orders
    case noOrders
    case field
    case phone

    var id: String { rawValue }
}

enum SalesmanShopOrderFilter: String, CaseIterable, Identifiable {
    case all
    case placed
    case notPlaced

    var id: String { rawValue }
}

struct SalesmanActivitiesDetailResponse: Decodable {
    var status: Bool
    var message: String
    var allShops: [SalesmanAllShop]
    var activities: SalesmanActivitiesData?
    var statusMap: [SalesmanStatusMapItem]

    enum CodingKeys: String, CodingKey {
        case status, message
        case allShops
        case activities = "activities_data"
        case statusMap = "status_map"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        allShops = (try? container.decode([SalesmanAllShop].self, forKey: .allShops)) ?? []
        activities = try? container.decode(SalesmanActivitiesData.self, forKey: .activities)
        statusMap = (try? container.decode([SalesmanStatusMapItem].self, forKey: .statusMap)) ?? []
    }
}

struct SalesmanAllShop: Identifiable, Hashable, Decodable {
    var sellerId: String
    var name: String
    var shopName: String
    var isOrderPlaced: Bool
    var beatId: Int?
    var beatName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case sellerId = "seller_id"
        case shopName = "shop_name"
        case isOrderPlaced
        case beatId = "beat_id"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        isOrderPlaced = container.decodeBoolLeniently(forKey: .isOrderPlaced) ?? false
        beatId = container.decodeIntLeniently(forKey: .beatId)
        beatName = container.decodeStringLeniently(forKey: .beatName)
    }

    var id: String { sellerId }

    var resolvedBeatName: String {
        guard let beatName, !beatName.isEmptyString else { return "Unassigned Beat" }
        return beatName
    }

    var displayShopName: String {
        shopName.isEmptyString ? name : shopName
    }
}

struct SalesmanActivitiesData: Decodable {
    var shopsVisited: [SalesmanShopInfo]
    var shopsGivenOrders: [SalesmanOrderInfo]
    var shopsNotGivenOrders: [SalesmanShopInfo]
    var ordersPhysical: [SalesmanPhysicalOrder]
    var ordersTelephonic: [SalesmanTelephonicOrder]

    enum CodingKeys: String, CodingKey {
        case shopsVisited = "how_many_shopes_visited"
        case shopsGivenOrders = "how_many_shopes_given_orders"
        case shopsNotGivenOrders = "how_many_shopes_not_given_orders"
        case ordersPhysical = "how_many_orders_taken_physically"
        case ordersTelephonic = "how_many_orders_taken_telephonic"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shopsVisited = (try? container.decode([SalesmanShopInfo].self, forKey: .shopsVisited)) ?? []
        shopsGivenOrders = (try? container.decode([SalesmanOrderInfo].self, forKey: .shopsGivenOrders)) ?? []
        shopsNotGivenOrders = (try? container.decode([SalesmanShopInfo].self, forKey: .shopsNotGivenOrders)) ?? []
        ordersPhysical = (try? container.decode([SalesmanPhysicalOrder].self, forKey: .ordersPhysical)) ?? []
        ordersTelephonic = (try? container.decode([SalesmanTelephonicOrder].self, forKey: .ordersTelephonic)) ?? []
    }

    init(
        shopsVisited: [SalesmanShopInfo],
        shopsGivenOrders: [SalesmanOrderInfo],
        shopsNotGivenOrders: [SalesmanShopInfo],
        ordersPhysical: [SalesmanPhysicalOrder],
        ordersTelephonic: [SalesmanTelephonicOrder]
    ) {
        self.shopsVisited = shopsVisited
        self.shopsGivenOrders = shopsGivenOrders
        self.shopsNotGivenOrders = shopsNotGivenOrders
        self.ordersPhysical = ordersPhysical
        self.ordersTelephonic = ordersTelephonic
    }
}

struct SalesmanShopInfo: Identifiable, Hashable, Decodable {
    var sellerId: String
    var name: String
    var shopName: String
    var visitDateTime: String?
    var lat: String?
    var lng: String?
    var shopAddress: String?
    var image: String?
    var remark: String?
    var nextVisitDate: String?
    var beatId: Int?
    var beatName: String?

    enum CodingKeys: String, CodingKey {
        case name, lat, lng, image, remark
        case sellerId = "seller_id"
        case shopName = "shop_name"
        case visitDateTime = "shop_visit_date_time"
        case shopAddress = "shop_address"
        case nextVisitDate = "next_visit_date"
        case beatId = "beat_id"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        visitDateTime = container.decodeStringLeniently(forKey: .visitDateTime)
        lat = container.decodeStringLeniently(forKey: .lat)
        lng = container.decodeStringLeniently(forKey: .lng)
        shopAddress = container.decodeStringLeniently(forKey: .shopAddress)
        image = container.decodeStringLeniently(forKey: .image)
        remark = container.decodeStringLeniently(forKey: .remark)
        nextVisitDate = container.decodeStringLeniently(forKey: .nextVisitDate)
        beatId = container.decodeIntLeniently(forKey: .beatId)
        beatName = container.decodeStringLeniently(forKey: .beatName)
    }

    var id: String { "\(sellerId)-\(shopName)-\(visitDateTime ?? "")" }

    var resolvedBeatName: String {
        guard let beatName, !beatName.isEmptyString else { return "Unassigned Beat" }
        return beatName
    }

    var displayShopName: String {
        shopName.isEmptyString ? name : shopName
    }

    var displayVisitDateTime: String {
        guard let visitDateTime, !visitDateTime.isEmptyString else { return "N/A" }
        return visitDateTime
    }

    var hasExtraInfo: Bool {
        !(shopAddress?.isEmptyString ?? true)
            || !(nextVisitDate?.isEmptyString ?? true)
            || !(remark?.isEmptyString ?? true)
            || hasMapCoordinates
            || !(image?.isEmptyString ?? true)
    }

    var hasMapCoordinates: Bool {
        guard let lat, let lng,
              let latValue = Double(lat), let lngValue = Double(lng),
              latValue != 0, lngValue != 0 else { return false }
        return true
    }
}

struct SalesmanOrderInfo: Identifiable, Hashable, Decodable {
    var orderId: String
    var sellerId: String
    var totalPrice: String
    var date: String
    var status: String
    var beatName: String?

    enum CodingKeys: String, CodingKey {
        case date, status
        case orderId = "order_id"
        case sellerId = "seller_id"
        case totalPrice = "total_price"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName)
    }

    var id: String { orderId }

    var resolvedBeatName: String {
        guard let beatName, !beatName.isEmptyString else { return "Unassigned Beat" }
        return beatName
    }
}

struct SalesmanPhysicalOrder: Identifiable, Hashable, Decodable {
    var orderId: String
    var sellerId: String
    var sellerName: String
    var shopName: String
    var totalPrice: String
    var orderDate: String
    var status: String
    var beatName: String?

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case shopName = "shop_name"
        case totalPrice = "total_price"
        case orderDate = "order_date"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName)
    }

    var id: String { orderId }

    var resolvedBeatName: String {
        guard let beatName, !beatName.isEmptyString else { return "Unassigned Beat" }
        return beatName
    }
}

struct SalesmanTelephonicOrder: Identifiable, Hashable, Decodable {
    var orderId: String
    var sellerId: String
    var sellerName: String
    var shopName: String
    var totalPrice: String
    var orderDate: String
    var status: String
    var beatName: String?

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case shopName = "shop_name"
        case totalPrice = "total_price"
        case orderDate = "order_date"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName)
    }

    var id: String { orderId }

    var resolvedBeatName: String {
        guard let beatName, !beatName.isEmptyString else { return "Unassigned Beat" }
        return beatName
    }
}

struct SalesmanStatusMapItem: Hashable, Decodable {
    var key: Int
    var label: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeIntLeniently(forKey: .key) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case key, label
    }
}
