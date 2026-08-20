//
//  MyProfileModels.swift
//  Truedata
//

import Foundation

struct MyProfileData {
    var name: String
    var roleName: String
    var staffId: String
    var profilePic: String
    var joiningDate: String
    var statusText: String
    var mobile: String
    var email: String
    var cityName: String
    var stateName: String
    var aadharFrontPic: String
    var aadharBackPic: String

    var locationText: String {
        let parts = [cityName, stateName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmptyString }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    var roleWithStaffId: String {
        let role = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = staffId.trimmingCharacters(in: .whitespacesAndNewlines)
        if role.isEmptyString && id.isEmptyString { return "—" }
        if id.isEmptyString { return role }
        if role.isEmptyString { return id }
        return "\(role) (\(id))"
    }
}

struct MyProfileResponse: Decodable {
    var status: Bool
    var message: String
    var data: MyProfileData

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

        if let payload = try? container.decode(MyProfileDTO.self, forKey: .data) {
            data = payload.asDomain
        } else {
            data = MyProfileData(
                name: "",
                roleName: "",
                staffId: "",
                profilePic: "",
                joiningDate: "",
                statusText: "",
                mobile: "",
                email: "",
                cityName: "",
                stateName: "",
                aadharFrontPic: "",
                aadharBackPic: ""
            )
        }
    }
}

private struct MyProfileDTO: Decodable {
    var name: String
    var roleName: String
    var staffId: String
    var profilePic: String
    var joiningDate: String
    var statusText: String
    var mobile: String
    var email: String
    var cityName: String
    var stateName: String
    var aadharFrontPic: String
    var aadharBackPic: String

    enum CodingKeys: String, CodingKey {
        case name, mobile, email
        case roleName = "role_name"
        case staffId = "staff_id"
        case profilePic = "profile_pic"
        case joiningDate = "joining_date"
        case statusText = "status_text"
        case cityName = "city_name"
        case stateName = "state_name"
        case aadharFrontPic = "addhar_front_pic"
        case aadharBackPic = "addhar_back_pic"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        roleName = container.decodeStringLeniently(forKey: .roleName) ?? ""
        staffId = container.decodeStringLeniently(forKey: .staffId) ?? ""
        profilePic = container.decodeStringLeniently(forKey: .profilePic) ?? ""
        joiningDate = container.decodeStringLeniently(forKey: .joiningDate) ?? ""
        statusText = container.decodeStringLeniently(forKey: .statusText) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        email = container.decodeStringLeniently(forKey: .email) ?? ""
        cityName = container.decodeStringLeniently(forKey: .cityName) ?? ""
        stateName = container.decodeStringLeniently(forKey: .stateName) ?? ""
        aadharFrontPic = container.decodeStringLeniently(forKey: .aadharFrontPic) ?? ""
        aadharBackPic = container.decodeStringLeniently(forKey: .aadharBackPic) ?? ""
    }

    var asDomain: MyProfileData {
        MyProfileData(
            name: name,
            roleName: roleName,
            staffId: staffId,
            profilePic: profilePic,
            joiningDate: joiningDate,
            statusText: statusText,
            mobile: mobile,
            email: email,
            cityName: cityName,
            stateName: stateName,
            aadharFrontPic: aadharFrontPic,
            aadharBackPic: aadharBackPic
        )
    }
}
