//
//  HomePrefetchModels.swift
//  Truedata
//

import Foundation

struct HomePrefetchAck: Decodable {
    var status: Bool
    var message: String?

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first
        } else {
            message = container.decodeStringLeniently(forKey: .message)
        }
    }
}

struct LocationConfigResponse: Decodable {
    var status: Bool
    var message: String
    var data: LocationConfigData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(LocationConfigData.self, forKey: .data)
    }
}

struct LocationConfigData: Decodable {
    var isUserWorking: Bool
    var priority: String
    var serviceEnabled: Bool
    var updateIntervalSeconds: String

    enum CodingKeys: String, CodingKey {
        case priority
        case isUserWorking = "is_user_working"
        case serviceEnabled = "service_enabled"
        case updateIntervalSeconds = "update_interval_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isUserWorking = container.decodeBoolLeniently(forKey: .isUserWorking) ?? false
        priority = container.decodeStringLeniently(forKey: .priority) ?? ""
        serviceEnabled = container.decodeBoolLeniently(forKey: .serviceEnabled) ?? false
        updateIntervalSeconds = container.decodeStringLeniently(forKey: .updateIntervalSeconds) ?? ""
    }
}

struct HomeSellerListResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }
}
