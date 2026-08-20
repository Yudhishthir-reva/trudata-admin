//
//  StaffActivitiesModels.swift
//  Truedata
//

import Foundation

struct StaffActivitiesHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var data: StaffActivitiesPaginatedData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(StaffActivitiesPaginatedData.self, forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
}

struct StaffActivitiesPaginatedData: Decodable {
    var currentPage: Int
    var lastPage: Int
    var perPage: Int
    var total: Int
    var activities: [StaffActivityItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        activities = (try? container.decode([StaffActivityItem].self, forKey: .data)) ?? []
    }
}

struct StaffActivityItem: Identifiable, Hashable {
    var id: String { staffId.nilIfEmpty ?? staffName }
    var staffId: String
    var staffName: String
    var ordersCount: Int
    var ordersTotal: Double
    var transactionsSum: Double
}

extension StaffActivityItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case staffId = "staff_id"
        case staffName = "staff_name"
        case ordersCount = "orders_count"
        case ordersTotal = "orders_total"
        case transactionsSum = "transactions_sum"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        ordersCount = container.decodeIntLeniently(forKey: .ordersCount)
            ?? Int(container.decodeStringLeniently(forKey: .ordersCount) ?? "") ?? 0
        ordersTotal = container.decodeDoubleLeniently(forKey: .ordersTotal)
            ?? Double(container.decodeStringLeniently(forKey: .ordersTotal) ?? "") ?? 0
        transactionsSum = container.decodeDoubleLeniently(forKey: .transactionsSum)
            ?? Double(container.decodeStringLeniently(forKey: .transactionsSum) ?? "") ?? 0
    }
}

struct StaffActivityDisplayRow: Identifiable, Hashable {
    var id: String
    var name: String
    var orders: Int
    var sales: Double
    var collection: Double

    init(name: String, orders: Int, sales: Double, collection: Double, id: String = UUID().uuidString) {
        self.id = id
        self.name = name
        self.orders = orders
        self.sales = sales
        self.collection = collection
    }

    init(item: StaffActivityItem) {
        id = item.id
        name = item.staffName
        orders = item.ordersCount
        sales = item.ordersTotal
        collection = item.transactionsSum
    }
}
