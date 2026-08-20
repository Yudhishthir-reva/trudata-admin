//
//  AddSellerModels.swift
//  Truedata
//

import Foundation
import UIKit

struct AddSellerTypeItem: Identifiable, Decodable {
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

struct AddSellerTypeResponse: Decodable {
    var status: Bool
    var message: String
    var data: [AddSellerTypeItem]

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
        data = (try? container.decode([AddSellerTypeItem].self, forKey: .data)) ?? []
    }
}

struct AddSellerStaffMember: Identifiable, Decodable {
    var id: Int
    var name: String
    var roleId: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case roleId = "role_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        roleId = container.decodeStringLeniently(forKey: .roleId) ?? ""
    }
}

struct AddSellerStaffListResponse: Decodable {
    var status: Bool
    var data: [AddSellerStaffMember]

    enum CodingKeys: String, CodingKey {
        case status, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        data = (try? container.decode([AddSellerStaffMember].self, forKey: .data)) ?? []
    }
}

struct SellerDetailData: Decodable {
    var id: Int
    var name: String
    var shopName: String
    var email: String
    var mobile: String
    var whatsappNo: String
    var sellerTypeId: String
    var beatId: String
    var dbBeatId: String
    var status: String
    var stateId: String
    var cityId: String
    var address: String
    var manualAddress: String
    var latitude: String
    var longitude: String
    var assignTo: String
    var assignToName: String
    var registeredByName: String
    var gstNo: String
    var landmark: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status, address, latitude, longitude, landmark
        case shopName = "shop_name"
        case email
        case whatsappNo = "whatsapp_no"
        case sellerTypeId = "sellertype_id"
        case beatId = "beat_id"
        case dbBeatId = "db_beat_id"
        case stateId = "state_id"
        case cityId = "city_id"
        case manualAddress = "manual_address"
        case assignTo = "assign_to"
        case assignToName = "assign_to_name"
        case registeredByName = "registered_by_name"
        case gstNo = "gst_no"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        whatsappNo = container.decodeStringLeniently(forKey: .whatsappNo) ?? ""
        sellerTypeId = container.decodeStringLeniently(forKey: .sellerTypeId) ?? ""
        beatId = container.decodeStringLeniently(forKey: .beatId) ?? ""
        dbBeatId = container.decodeStringLeniently(forKey: .dbBeatId) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        stateId = container.decodeStringLeniently(forKey: .stateId) ?? ""
        cityId = container.decodeStringLeniently(forKey: .cityId) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        manualAddress = container.decodeStringLeniently(forKey: .manualAddress) ?? ""
        latitude = container.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = container.decodeStringLeniently(forKey: .longitude) ?? ""
        assignTo = container.decodeStringLeniently(forKey: .assignTo) ?? ""
        assignToName = container.decodeStringLeniently(forKey: .assignToName) ?? ""
        registeredByName = container.decodeStringLeniently(forKey: .registeredByName) ?? ""
        gstNo = container.decodeStringLeniently(forKey: .gstNo) ?? ""
        landmark = container.decodeStringLeniently(forKey: .landmark) ?? ""
    }
}

struct SellerDetailResponse: Decodable {
    var status: Bool
    var message: String
    var data: SellerDetailData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(SellerDetailData.self, forKey: .data)
    }
}

struct AddSellerFormErrors {
    var sellerName: String?
    var shopName: String?
    var mobile: String?
    var email: String?
    var gstNo: String?
    var state: String?
    var city: String?
    var beat: String?
    var sellerType: String?
    var assignedTo: String?

    var hasErrors: Bool {
        sellerName != nil || shopName != nil || mobile != nil || email != nil ||
        gstNo != nil || state != nil || city != nil || beat != nil ||
        sellerType != nil || assignedTo != nil
    }
}

enum AddSellerPhotoKind: String, Identifiable {
    case profile
    case aadharFront
    case aadharBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile Photo"
        case .aadharFront: return "Aadhar Front"
        case .aadharBack: return "Aadhar Back"
        }
    }

    var fieldName: String {
        switch self {
        case .profile: return "profile_pic"
        case .aadharFront: return "aadhar_front_pic"
        case .aadharBack: return "aadhar_back_pic"
        }
    }
}

extension UIImage {
    func compressedJPEGData(maxBytes: Int = 800_000) -> Data? {
        var quality: CGFloat = 0.85
        guard var data = jpegData(compressionQuality: quality) else { return nil }
        while data.count > maxBytes && quality > 0.2 {
            quality -= 0.1
            guard let next = jpegData(compressionQuality: quality) else { break }
            data = next
        }
        return data
    }
}
