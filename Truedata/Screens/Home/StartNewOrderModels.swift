//
//  StartNewOrderModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum StartNewOrderSelectionStep: Int, CaseIterable {
    case state = 0
    case city = 1
    case beat = 2
}

struct StartNewOrderAreaPreference: Decodable {
    var selectedState: String?
    var selectedCity: String?
    var selectedBeat: String?

    enum CodingKeys: String, CodingKey {
        case selectedState, selectedCity, selectedBeat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedState = container.decodeStringLeniently(forKey: .selectedState)
        selectedCity = container.decodeStringLeniently(forKey: .selectedCity)
        selectedBeat = container.decodeStringLeniently(forKey: .selectedBeat)
    }
}

struct StartNewOrderAllAreaResponse: Decodable {
    var status: Bool
    var states: [OrderInsightsStateArea]
    var preference: StartNewOrderAreaPreference?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let dataContainer = try? container.nestedContainer(keyedBy: AreaDataKey.self, forKey: .data) {
            states = (try? dataContainer.decode([OrderInsightsStateArea].self, forKey: .states)) ?? []
            preference = try? dataContainer.decode(StartNewOrderAreaPreference.self, forKey: .preference)
        } else {
            states = []
            preference = nil
        }
    }

    private enum AreaDataKey: String, CodingKey {
        case states = "0"
        case preference
    }
}

struct StartNewOrderStatusResponse: Decodable {
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

struct StartNewOrderSellerListResponse: Decodable {
    var status: Bool
    var message: String
    var sellers: [StartNewOrderSeller]

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
        sellers = (try? container.decode([StartNewOrderSeller].self, forKey: .data)) ?? []
    }
}

struct StartNewOrderSeller: Identifiable, Decodable, Hashable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String
    var sellerId: String
    var beatId: String
    var status: String
    var profilePic: String
    var createOrderStatus: Bool
    var isApproved: Bool
    var shopVisitedStatus: String
    var shopVisitedLocationIncorrect: Bool
    var colorId: Int?
    var colorDescription: String?
    var transactionCount: Int
    var whatsappNo: String
    var email: String
    var address: String
    var cityId: String
    var stateId: String
    var sellerTypeId: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status, address, email
        case shopName = "shop_name"
        case sellerId = "seller_id"
        case beatId = "beat_id"
        case profilePic = "profile_pic"
        case createOrderStatus = "create_order_status"
        case isApproved = "is_approved"
        case shopVisitedStatus = "shop_visited_status"
        case shopVisitedLocationIncorrect = "shop_visited_location_incorrect"
        case colorId = "color_id"
        case colorDescription = "color_description"
        case transactionCount = "transaction_count"
        case whatsappNo = "whatsapp_no"
        case cityId = "city_id"
        case stateId = "state_id"
        case sellerTypeId = "sellertype_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        beatId = container.decodeStringLeniently(forKey: .beatId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        createOrderStatus = container.decodeBoolLeniently(forKey: .createOrderStatus) ?? false
        isApproved = container.decodeBoolLeniently(forKey: .isApproved) ?? false
        shopVisitedStatus = container.decodeStringLeniently(forKey: .shopVisitedStatus) ?? ""
        shopVisitedLocationIncorrect = container.decodeBoolLeniently(forKey: .shopVisitedLocationIncorrect) ?? false
        colorId = container.decodeIntLeniently(forKey: .colorId)
        colorDescription = container.decodeStringLeniently(forKey: .colorDescription)
        transactionCount = container.decodeIntLeniently(forKey: .transactionCount) ?? 0
        whatsappNo = container.decodeStringLeniently(forKey: .whatsappNo) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        cityId = container.decodeStringLeniently(forKey: .cityId) ?? ""
        stateId = container.decodeStringLeniently(forKey: .stateId) ?? ""
        sellerTypeId = container.decodeStringLeniently(forKey: .sellerTypeId) ?? ""
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
    }

    var displayName: String {
        shopName.isEmptyString ? name : shopName
    }

    var joinedDate: String {
        createdAt.count >= 10 ? String(createdAt.prefix(10)) : createdAt
    }

    var accessStatusLabel: String {
        createOrderStatus ? "Active" : "Restricted"
    }

    var contactLine: String {
        if name.isEmptyString { return mobile }
        if mobile.isEmptyString { return name }
        return "\(name) • \(mobile)"
    }

    var flagColor: Color? {
        switch colorId {
        case 1: return DashboardTheme.successGreen
        case 3: return DashboardTheme.dangerRed
        case 4: return DashboardTheme.pickupOrange
        default: return nil
        }
    }

    var isNotVisited: Bool {
        shopVisitedStatus.lowercased().hasPrefix("not visited")
    }

    var isOrderPlaced: Bool {
        shopVisitedStatus.lowercased().hasPrefix("visited + order placed")
    }

    var isNoOrder: Bool {
        shopVisitedStatus.lowercased().hasPrefix("visited but no order")
    }

    var isUnknownVisitStatus: Bool {
        !isNotVisited && !isOrderPlaced && !isNoOrder
    }
}

enum StartNewOrderSellerTab: String, CaseIterable, Identifiable {
    case notVisited
    case orderPlaced
    case noOrder
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notVisited: return "Not Visited"
        case .orderPlaced: return "Order Placed"
        case .noOrder: return "No Order"
        case .unknown: return "Unknown"
        }
    }

    func matches(_ seller: StartNewOrderSeller) -> Bool {
        switch self {
        case .notVisited: return seller.isNotVisited
        case .orderPlaced: return seller.isOrderPlaced
        case .noOrder: return seller.isNoOrder
        case .unknown: return seller.isUnknownVisitStatus
        }
    }
}

struct StartNewOrderSellerTabItem: Identifiable {
    var tab: StartNewOrderSellerTab
    var count: Int

    var id: String { tab.id }
    var title: String { tab.title }
}
