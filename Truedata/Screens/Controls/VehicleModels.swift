//
//  VehicleModels.swift
//  Truedata
//

import Foundation

enum VehicleListTab: String, CaseIterable, Identifiable {
    case vehicles = "Vehicles"
    case riders = "Riders"

    var id: String { rawValue }
}

struct AdminVehicleListResponse: Decodable {
    var status: Bool
    var message: String
    var data: AdminVehicleListData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(AdminVehicleListData.self, forKey: .data)) ?? AdminVehicleListData()
    }
}

struct AdminVehicleListData: Decodable {
    var vehicles: [AdminVehicleItem]
    var riders: [AdminVehicleRider]

    enum CodingKeys: String, CodingKey {
        case vehicles = "vechiles"
        case riders
    }

    init(vehicles: [AdminVehicleItem] = [], riders: [AdminVehicleRider] = []) {
        self.vehicles = vehicles
        self.riders = riders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicles = (try? container.decode([AdminVehicleItem].self, forKey: .vehicles)) ?? []
        riders = (try? container.decode([AdminVehicleRider].self, forKey: .riders)) ?? []
    }
}

struct AdminVehicleItem: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var model: String
    var plateNumber: String
    var status: String
    var inUse: String
    var isDelete: String
    var createdAt: String
    var updatedAt: String
    var vehicleAssigned: VehicleAllocation?

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case model = "modal"
        case plateNumber = "no_plate"
        case inUse = "in_use"
        case isDelete = "is_delete"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case vehicleAssigned = "vehicle_assigned"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        model = container.decodeStringLeniently(forKey: .model) ?? ""
        plateNumber = container.decodeStringLeniently(forKey: .plateNumber) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        inUse = container.decodeStringLeniently(forKey: .inUse) ?? "0"
        isDelete = container.decodeStringLeniently(forKey: .isDelete) ?? ""
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
        updatedAt = container.decodeStringLeniently(forKey: .updatedAt) ?? ""
        vehicleAssigned = try? container.decode(VehicleAllocation.self, forKey: .vehicleAssigned)
    }

    var isAvailable: Bool { inUse == "0" }

    var usageStatusLabel: String {
        switch inUse {
        case "0": return "Available"
        case "1": return "Assigned"
        case "2": return "In Use"
        default: return "Unknown"
        }
    }

    var isActive: Bool { status == "1" }
}

struct VehicleAllocation: Hashable, Decodable {
    var id: Int
    var vehicleId: String?
    var riderId: String

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vechile_id"
        case riderId = "rider_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        vehicleId = container.decodeStringLeniently(forKey: .vehicleId)
        riderId = container.decodeStringLeniently(forKey: .riderId) ?? ""
    }
}

struct AdminVehicleRider: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var email: String
    var mobile: String
    var staffId: String
    var status: String
    var vehicleAssignment: RiderVehicleAssignment?

    enum CodingKeys: String, CodingKey {
        case id, name, email, mobile, status
        case staffId = "staff_id"
        case vehicleAssignment = "vechile_assigned"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        vehicleAssignment = try? container.decode(RiderVehicleAssignment.self, forKey: .vehicleAssignment)
    }

    var isActive: Bool { status == "1" }
    var hasVehicleAssigned: Bool { vehicleAssignment != nil }
    var assignedVehicleName: String? { vehicleAssignment?.vehicle?.name }
    var assignedVehiclePlate: String? { vehicleAssignment?.vehicle?.plateNumber }
}

struct RiderVehicleAssignment: Hashable, Decodable {
    var id: Int
    var vehicleId: String?
    var riderId: String
    var status: String
    var vehicle: AdminVehicleItem?

    enum CodingKeys: String, CodingKey {
        case id, status, vehicle
        case vehicleId = "vechile_id"
        case riderId = "rider_id"
        case vehicleNested = "vechile"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        vehicleId = container.decodeStringLeniently(forKey: .vehicleId)
        riderId = container.decodeStringLeniently(forKey: .riderId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        vehicle = (try? container.decode(AdminVehicleItem.self, forKey: .vehicleNested))
            ?? (try? container.decode(AdminVehicleItem.self, forKey: .vehicle))
    }
}

struct VehicleHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var data: VehicleHistoryData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(VehicleHistoryData.self, forKey: .data)
    }
}

struct VehicleHistoryData: Decodable {
    var vehicle: AdminVehicleItem?
    var logs: [VehicleHistoryLog]

    enum CodingKeys: String, CodingKey {
        case vehicle, logs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicle = try? container.decode(AdminVehicleItem.self, forKey: .vehicle)
        logs = (try? container.decode([VehicleHistoryLog].self, forKey: .logs)) ?? []
    }
}

struct VehicleHistoryLog: Identifiable, Hashable, Decodable {
    var id: Int
    var vehicleId: String
    var riderId: String
    var status: String
    var inUse: String
    var dateTime: String
    var createdAt: String
    var rider: AdminVehicleRider?

    enum CodingKeys: String, CodingKey {
        case id, status, rider
        case vehicleId = "vechile_id"
        case riderId = "rider_id"
        case inUse = "in_use"
        case dateTime = "date_time"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        vehicleId = container.decodeStringLeniently(forKey: .vehicleId) ?? ""
        riderId = container.decodeStringLeniently(forKey: .riderId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        inUse = container.decodeStringLeniently(forKey: .inUse) ?? ""
        dateTime = container.decodeStringLeniently(forKey: .dateTime) ?? ""
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
        rider = try? container.decode(AdminVehicleRider.self, forKey: .rider)
    }

    var statusLabel: String {
        switch inUse {
        case "1": return "Checked Out"
        case "2": return "Assigned"
        case "0": return "Returned / Free"
        default: return "Unknown"
        }
    }
}

struct VehicleFormData: Equatable {
    var vehicleId: String?
    var name: String = ""
    var model: String = ""
    var plateNumber: String = ""
    var status: String = "1"

    var isEditMode: Bool { vehicleId != nil }
}

struct VehicleStatusMessageResponse: Decodable {
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
