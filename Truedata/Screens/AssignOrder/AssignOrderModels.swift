//
//  AssignOrderModels.swift
//  Truedata
//

import Foundation

struct RiderListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [RiderItem]

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
        data = (try? container.decode([RiderItem].self, forKey: .data)) ?? []
    }
}

struct RiderItem: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct BeatWithOrdersResponse: Decodable {
    var status: Bool
    var message: String
    var data: [BeatWithOrdersItem]

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
        data = (try? container.decode([BeatWithOrdersItem].self, forKey: .data)) ?? []
    }
}

struct BeatWithOrdersItem: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct VehicleListResponse: Decodable {
    var status: Bool
    var message: String
    var vehicleList: [VehicleItem]

    enum CodingKeys: String, CodingKey {
        case status, message
        case vehicleList = "vehicleList"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        vehicleList = (try? container.decode([VehicleItem].self, forKey: .vehicleList)) ?? []
    }
}

struct VehicleItem: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var modal: String
    var noPlate: String
    var status: String
    var inUse: String
    var riderId: Int
    var riderName: String

    var isSelectable: Bool { inUse != "2" }
    var isVisible: Bool { status == "1" }

    var usageStatusLabel: String {
        switch inUse {
        case "0": return "Available"
        case "1": return "Assigned"
        case "2": return "In Use"
        default: return "Unknown"
        }
    }

    var isAssignedToAnotherRider: Bool {
        inUse == "1" && !riderName.isEmptyString
    }

    enum CodingKeys: String, CodingKey {
        case id, name, modal, status, rider
        case noPlate = "no_plate"
        case inUse = "in_use"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        modal = container.decodeStringLeniently(forKey: .modal) ?? ""
        noPlate = container.decodeStringLeniently(forKey: .noPlate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? "0"
        inUse = container.decodeStringLeniently(forKey: .inUse) ?? "0"

        if let riderContainer = try? container.nestedContainer(keyedBy: RiderKeys.self, forKey: .rider) {
            riderId = riderContainer.decodeIntLeniently(forKey: .id) ?? 0
            riderName = riderContainer.decodeStringLeniently(forKey: .name) ?? ""
        } else {
            riderId = 0
            riderName = ""
        }
    }

    private enum RiderKeys: String, CodingKey {
        case id, name
    }
}

struct AssignOrderListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [AssignOrderDTO]

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
        data = (try? container.decode([AssignOrderDTO].self, forKey: .data)) ?? []
    }
}

struct AssignOrderDTO: Decodable {
    var orderId: Int
    var orderNo: String
    var sellerShopName: String
    var staffName: String
    var totalPrice: String
    var sellerAddress: String
    var status: String
    var orderNotDelivered: Bool
    var orderDate: String
    var beatId: String
    var beatName: String

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case orderNo = "order_no"
        case sellerShopName = "seller_shop_name"
        case staffName = "staff_name"
        case totalPrice = "total_price"
        case sellerAddress = "seller_address"
        case orderNotDelivered = "order_not_delivered"
        case orderDate = "order_date"
        case beatId = "beat_id"
        case beatName = "beat_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        sellerAddress = container.decodeStringLeniently(forKey: .sellerAddress) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        orderNotDelivered = container.decodeBoolLeniently(forKey: .orderNotDelivered) ?? false
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        beatId = container.decodeStringLeniently(forKey: .beatId) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
    }

    var asModel: AssignOrderItem {
        AssignOrderItem(
            id: String(orderId),
            invoiceId: orderNo,
            sellerShopName: sellerShopName,
            staffName: staffName,
            totalAmount: totalPrice,
            sellerAddress: sellerAddress,
            orderStatus: status,
            orderNotDelivered: orderNotDelivered,
            date: orderDate,
            beatId: beatId,
            beatName: beatName
        )
    }
}

struct AssignOrderItem: Identifiable, Hashable {
    let id: String
    let invoiceId: String
    let sellerShopName: String
    let staffName: String
    let totalAmount: String
    let sellerAddress: String
    let orderStatus: String
    let orderNotDelivered: Bool
    let date: String
    let beatId: String
    let beatName: String
}
