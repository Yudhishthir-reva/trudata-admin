//
//  RegisteredSellersModels.swift
//  Truedata
//

import Foundation

struct RegisteredSellerItem: Identifiable, Decodable {
    var id: Int
    var name: String
    var shopName: String
    var email: String
    var mobile: String
    var whatsappNo: String
    var beatId: String
    var status: String
    var stateId: String
    var cityId: String
    var address: String
    var latitude: String
    var longitude: String
    var colorId: Int?
    var colorDescription: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, mobile, status, address, latitude, longitude
        case shopName = "shop_name"
        case whatsappNo = "whatsapp_no"
        case beatId = "beat_id"
        case stateId = "state_id"
        case cityId = "city_id"
        case colorId = "color_id"
        case colorDescription = "color_description"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        whatsappNo = container.decodeStringLeniently(forKey: .whatsappNo) ?? ""
        beatId = container.decodeStringLeniently(forKey: .beatId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        stateId = container.decodeStringLeniently(forKey: .stateId) ?? ""
        cityId = container.decodeStringLeniently(forKey: .cityId) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        latitude = container.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = container.decodeStringLeniently(forKey: .longitude) ?? ""
        colorId = container.decodeIntLeniently(forKey: .colorId)
        colorDescription = container.decodeStringLeniently(forKey: .colorDescription)
    }

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame || status == "1"
    }

    var statusLabel: String {
        isActive ? "ACTIVE" : "INACTIVE"
    }

    var cardTitle: String {
        if shopName.isEmptyString {
            return name
        }
        return "\(name) (\(shopName))"
    }
}

struct RegisteredSellerListResponse: Decodable {
    var status: Bool
    var message: String
    var showDeactBtn: Bool
    var data: RegisteredSellerPage

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case showDeactBtn = "showDeactBtn"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        showDeactBtn = container.decodeBoolLeniently(forKey: .showDeactBtn) ?? false
        data = (try? container.decode(RegisteredSellerPage.self, forKey: .data)) ?? RegisteredSellerPage()
    }
}

struct RegisteredSellerPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var sellers: [RegisteredSellerItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case sellers = "data"
    }

    init(
        currentPage: Int = 0,
        lastPage: Int = 0,
        total: Int = 0,
        sellers: [RegisteredSellerItem] = []
    ) {
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
        sellers = (try? container.decode([RegisteredSellerItem].self, forKey: .sellers)) ?? []
    }
}

struct SellerStatusMessageResponse: Decodable {
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
