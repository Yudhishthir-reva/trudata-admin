//
//  DashboardModels.swift
//  Truedata
//

import Foundation

struct DashboardResponse: Decodable {
    var status: Bool
    var role: String
    var message: String
    var maintenanceMode: Bool
    var attendanceScreen: Bool
    var attendanceRoute: String
    var isBeatSelected: Bool
    var data: DashboardData?

    enum CodingKeys: String, CodingKey {
        case status, role, message, data
        case maintenanceMode = "maintenance_mode"
        case attendanceScreen = "attendance_screen"
        case attendanceRoute = "attendance_route"
        case isBeatSelected = "is_beat_selected"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        role = container.decodeStringLeniently(forKey: .role) ?? ""
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        maintenanceMode = container.decodeBoolLeniently(forKey: .maintenanceMode) ?? false
        attendanceScreen = container.decodeBoolLeniently(forKey: .attendanceScreen) ?? false
        attendanceRoute = container.decodeStringLeniently(forKey: .attendanceRoute) ?? "attendance"
        isBeatSelected = container.decodeBoolLeniently(forKey: .isBeatSelected) ?? true
        data = try? container.decode(DashboardData.self, forKey: .data)
    }
}

struct DashboardData: Decodable {
    var screenTitle: String
    var profileUrl: String
    var columns: Int
    var components: [DashboardComponentGroup]

    enum CodingKeys: String, CodingKey {
        case components, columns
        case screenTitle = "screen_title"
        case profileUrl = "profile_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screenTitle = container.decodeStringLeniently(forKey: .screenTitle) ?? ""
        profileUrl = container.decodeStringLeniently(forKey: .profileUrl) ?? ""
        columns = Int(container.decodeStringLeniently(forKey: .columns) ?? "") ?? 2
        components = (try? container.decode([DashboardComponentGroup].self, forKey: .components)) ?? []
    }

    var items: [DashboardItem] {
        sections.flatMap(\.items)
    }

    var sections: [DashboardSection] {
        components
            .sorted { $0.orderInt < $1.orderInt }
            .map { group in
                DashboardSection(
                    title: group.title,
                    order: group.orderInt,
                    items: group.subMenu.flatMap(\.componentData.items)
                )
            }
            .filter { !$0.items.isEmpty }
    }
}

struct DashboardSection: Identifiable {
    var id: String { "\(order)_\(title)" }
    let title: String
    let order: Int
    let items: [DashboardItem]
}

struct DashboardComponentGroup: Decodable {
    var title: String
    var order: String
    var subMenu: [DashboardSubMenu]

    var orderInt: Int { Int(order) ?? Int.max }

    enum CodingKeys: String, CodingKey {
        case title, order
        case subMenu = "sub_menu"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeStringLeniently(forKey: .title) ?? ""
        order = container.decodeStringLeniently(forKey: .order) ?? ""
        subMenu = (try? container.decode([DashboardSubMenu].self, forKey: .subMenu)) ?? []
    }
}

struct DashboardSubMenu: Decodable {
    var componentType: String
    var componentData: DashboardComponentData

    enum CodingKeys: String, CodingKey {
        case componentType = "component_type"
        case componentData = "component_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        componentType = container.decodeStringLeniently(forKey: .componentType) ?? ""
        componentData = (try? container.decode(DashboardComponentData.self, forKey: .componentData))
            ?? DashboardComponentData(items: [])
    }
}

struct DashboardComponentData: Decodable {
    var items: [DashboardItem]
}

struct DashboardItem: Decodable, Identifiable {
    var parentId: Int
    var itemId: String
    var title: String
    var imageUrl: String
    var route: String
    var payload: JSONValue?

    var id: String { "\(parentId)_\(itemId)_\(route)" }

    enum CodingKeys: String, CodingKey {
        case title, action, data
        case parentId = "parent_id"
        case itemId = "item_id"
        case imageUrl = "image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parentId = container.decodeIntLeniently(forKey: .parentId) ?? 0
        itemId = container.decodeStringLeniently(forKey: .itemId) ?? ""
        title = container.decodeStringLeniently(forKey: .title) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .imageUrl) ?? ""
        payload = try? container.decode(JSONValue.self, forKey: .data)

        if let action = try? container.decode(DashboardAction.self, forKey: .action) {
            route = action.payload?.route ?? ""
        } else {
            route = ""
        }
    }
}

struct DashboardAction: Decodable {
    var payload: DashboardRoutePayload?
}

struct DashboardRoutePayload: Decodable {
    var route: String
}

struct StatusMessageResponse: Decodable {
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
