//
//  LoginRequestsModels.swift
//  Truedata
//

import Foundation
import SwiftUI

enum LoginRequestTab: String, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var apiStatus: String { rawValue }
}

struct DeviceChangeRequestItem: Identifiable, Hashable {
    var id: Int
    var userId: Int
    var userName: String
    var userMobile: String
    var oldDeviceId: String
    var oldDeviceModel: String
    var newDeviceId: String
    var newDeviceModel: String
    var status: String
    var requestedAt: String
    var resolvedAt: String

    var statusLabel: String {
        status.uppercased()
    }

    var statusColor: Color {
        switch status.lowercased() {
        case "pending": return DashboardTheme.warningYellow
        case "approved": return DashboardTheme.successGreen
        case "rejected": return DashboardTheme.dangerRed
        default: return DashboardTheme.neutralMedium
        }
    }

    var isPending: Bool {
        status.lowercased() == "pending"
    }
}

struct DeviceChangeHistoryItem: Identifiable, Hashable {
    var id: String { "\(oldDeviceId)-\(newDeviceId)-\(changedAt)" }
    var oldDeviceId: String
    var oldDeviceModel: String
    var newDeviceId: String
    var newDeviceModel: String
    var changedAt: String
}

struct DeviceChangeRequestListResponse: Decodable {
    var status: Bool
    var data: [DeviceChangeRequestItem]

    enum CodingKeys: String, CodingKey {
        case status, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        data = (try? container.decode([DeviceChangeRequestDTO].self, forKey: .data))?.map(\.asDomain) ?? []
    }
}

private struct DeviceChangeRequestDTO: Decodable {
    var id: Int
    var userId: Int
    var userName: String
    var userMobile: String
    var oldDeviceId: String
    var oldDeviceModel: String
    var newDeviceId: String
    var newDeviceModel: String
    var status: String
    var requestedAt: String
    var resolvedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userMobile = "user_mobile"
        case oldDeviceId = "old_device_id"
        case oldDeviceModel = "old_device_model"
        case newDeviceId = "new_device_id"
        case newDeviceModel = "new_device_model"
        case status
        case requestedAt = "requested_at"
        case resolvedAt = "resolved_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        userId = container.decodeIntLeniently(forKey: .userId) ?? 0
        userName = container.decodeStringLeniently(forKey: .userName) ?? ""
        userMobile = container.decodeStringLeniently(forKey: .userMobile) ?? ""
        oldDeviceId = container.decodeStringLeniently(forKey: .oldDeviceId) ?? ""
        oldDeviceModel = container.decodeStringLeniently(forKey: .oldDeviceModel) ?? ""
        newDeviceId = container.decodeStringLeniently(forKey: .newDeviceId) ?? ""
        newDeviceModel = container.decodeStringLeniently(forKey: .newDeviceModel) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        requestedAt = container.decodeStringLeniently(forKey: .requestedAt) ?? ""
        resolvedAt = container.decodeStringLeniently(forKey: .resolvedAt) ?? ""
    }

    var asDomain: DeviceChangeRequestItem {
        DeviceChangeRequestItem(
            id: id,
            userId: userId,
            userName: userName,
            userMobile: userMobile,
            oldDeviceId: oldDeviceId,
            oldDeviceModel: oldDeviceModel,
            newDeviceId: newDeviceId,
            newDeviceModel: newDeviceModel,
            status: status,
            requestedAt: requestedAt,
            resolvedAt: resolvedAt
        )
    }
}

struct DeviceChangeHistoryResponse: Decodable {
    var status: Bool
    var data: [DeviceChangeHistoryItem]

    enum CodingKeys: String, CodingKey {
        case status, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        data = (try? container.decode([DeviceChangeHistoryDTO].self, forKey: .data))?.map(\.asDomain) ?? []
    }
}

private struct DeviceChangeHistoryDTO: Decodable {
    var oldDeviceId: String
    var oldDeviceModel: String
    var newDeviceId: String
    var newDeviceModel: String
    var changedAt: String

    enum CodingKeys: String, CodingKey {
        case oldDeviceId = "old_device_id"
        case oldDeviceModel = "old_device_model"
        case newDeviceId = "new_device_id"
        case newDeviceModel = "new_device_model"
        case changedAt = "changed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        oldDeviceId = container.decodeStringLeniently(forKey: .oldDeviceId) ?? ""
        oldDeviceModel = container.decodeStringLeniently(forKey: .oldDeviceModel) ?? ""
        newDeviceId = container.decodeStringLeniently(forKey: .newDeviceId) ?? ""
        newDeviceModel = container.decodeStringLeniently(forKey: .newDeviceModel) ?? ""
        changedAt = container.decodeStringLeniently(forKey: .changedAt) ?? ""
    }

    var asDomain: DeviceChangeHistoryItem {
        DeviceChangeHistoryItem(
            oldDeviceId: oldDeviceId,
            oldDeviceModel: oldDeviceModel,
            newDeviceId: newDeviceId,
            newDeviceModel: newDeviceModel,
            changedAt: changedAt
        )
    }
}
