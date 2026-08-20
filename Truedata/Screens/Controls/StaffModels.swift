//
//  StaffModels.swift
//  Truedata
//

import Foundation
import UIKit

enum StaffMemberTab: String, CaseIterable, Identifiable {
    case active = "Active"
    case inactive = "Inactive"

    var id: String { rawValue }
}

enum StaffPhotoKind: String, Identifiable {
    case profile
    case aadharFront
    case aadharBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile Photo"
        case .aadharFront: return "Aadhaar Card (Front)"
        case .aadharBack: return "Aadhaar Card (Back)"
        }
    }

    var placeholder: String {
        switch self {
        case .profile: return "Upload Profile Photo"
        case .aadharFront: return "Upload Aadhaar Front"
        case .aadharBack: return "Upload Aadhaar Back"
        }
    }
}

struct RegisteredStaffMember: Identifiable, Hashable, Decodable {
    var id: Int
    var staffId: String
    var name: String
    var mobile: String
    var email: String
    var roleId: String
    var stateId: String
    var cityId: String
    var joiningDate: String
    var status: String
    var profilePic: String
    var aadharFrontPic: String
    var aadharBackPic: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, email, status
        case staffId = "staff_id"
        case roleId = "role_id"
        case stateId = "state_id"
        case cityId = "city_id"
        case joiningDate = "joining_date"
        case profilePic = "profile_pic"
        case aadharFrontPic = "addhar_front_pic"
        case aadharBackPic = "addhar_back_pic"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        roleId = container.decodeStringLeniently(forKey: .roleId) ?? ""
        stateId = container.decodeStringLeniently(forKey: .stateId) ?? ""
        cityId = container.decodeStringLeniently(forKey: .cityId) ?? ""
        joiningDate = container.decodeStringLeniently(forKey: .joiningDate) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        aadharFrontPic = container.decodeStringLeniently(forKey: .aadharFrontPic) ?? ""
        aadharBackPic = container.decodeStringLeniently(forKey: .aadharBackPic) ?? ""
    }

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame
    }
}

struct RegisteredStaffListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [RegisteredStaffMember]

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
        data = (try? container.decode([RegisteredStaffMember].self, forKey: .data)) ?? []
    }
}

struct StaffRoleItem: Identifiable, Decodable {
    var id: Int
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct StaffRoleResponse: Decodable {
    var status: Bool
    var data: [StaffRoleItem]

    enum CodingKeys: String, CodingKey {
        case status, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        data = (try? container.decode([StaffRoleItem].self, forKey: .data)) ?? []
    }
}

struct StaffFormErrors {
    var name: String?
    var phone: String?
    var state: String?
    var city: String?
    var role: String?
    var joiningDate: String?

    var hasErrors: Bool {
        [name, phone, state, city, role, joiningDate].contains { $0 != nil }
    }
}

struct StaffStatusMessageResponse: Decodable {
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
