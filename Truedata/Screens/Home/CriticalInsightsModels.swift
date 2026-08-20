//
//  CriticalInsightsModels.swift
//  Truedata
//

import Foundation

enum CriticalInsightsTab: String, CaseIterable, Identifiable {
    case noOrders
    case noPayments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noOrders: return "No Orders"
        case .noPayments: return "No Payments"
        }
    }

    var info: String {
        switch self {
        case .noOrders: return "List of sellers with no orders under 10 days"
        case .noPayments: return "List of sellers with no payments under 10 days"
        }
    }
}

struct CriticalInsightsSellerItem: Identifiable, Hashable {
    var id: Int
    var name: String
    var beatName: String
    var staffName: String
    var imageURL: String
    var daysSinceText: String

    var daysNumber: String {
        daysSinceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first ?? ""
    }

    var daysLabel: String {
        let parts = daysSinceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .dropFirst()
        return parts.joined(separator: " ").uppercased()
    }
}

struct CriticalInsightsData {
    var noOrderSellers: [CriticalInsightsSellerItem]
    var noPaymentSellers: [CriticalInsightsSellerItem]

    var availableBeats: [String] {
        let beats = (noOrderSellers.map(\.beatName) + noPaymentSellers.map(\.beatName))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmptyString }
        return Array(Set(beats)).sorted()
    }
}

struct CriticalInsightsResponse: Decodable {
    var status: Bool
    var message: String
    var data: CriticalInsightsData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let payload = try? container.decode(CriticalInsightsPayload.self, forKey: .data) {
            data = payload.asDomain
        } else {
            data = CriticalInsightsData(noOrderSellers: [], noPaymentSellers: [])
        }
    }
}

private struct CriticalInsightsPayload: Decodable {
    var noOrderSellers: [CriticalInsightsSellerDTO]
    var noPaymentSellers: [CriticalInsightsSellerDTO]

    enum CodingKeys: String, CodingKey {
        case noOrderSellers = "sellers_no_orders_last_10_days"
        case noPaymentSellers = "sellers_no_transactions_last_10_days"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        noOrderSellers = (try? container.decode([CriticalInsightsSellerDTO].self, forKey: .noOrderSellers)) ?? []
        noPaymentSellers = (try? container.decode([CriticalInsightsSellerDTO].self, forKey: .noPaymentSellers)) ?? []
    }

    var asDomain: CriticalInsightsData {
        CriticalInsightsData(
            noOrderSellers: noOrderSellers.map(\.asDomain),
            noPaymentSellers: noPaymentSellers.map(\.asDomain)
        )
    }
}

private struct CriticalInsightsSellerDTO: Decodable {
    var id: Int
    var name: String
    var beatName: String
    var staffName: String
    var imageURL: String
    var daysSinceText: String

    enum CodingKeys: String, CodingKey {
        case id, name, image
        case beatName = "beat_name"
        case staffName = "staff_name"
        case daysSinceText = "days_since_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        imageURL = container.decodeStringLeniently(forKey: .image) ?? ""
        daysSinceText = container.decodeStringLeniently(forKey: .daysSinceText) ?? ""
    }

    var asDomain: CriticalInsightsSellerItem {
        CriticalInsightsSellerItem(
            id: id,
            name: name,
            beatName: beatName,
            staffName: staffName,
            imageURL: imageURL,
            daysSinceText: daysSinceText
        )
    }
}

struct CriticalInsightsExcelExportResult {
    var data: Data
    var filename: String
}
