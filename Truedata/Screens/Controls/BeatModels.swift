//
//  BeatModels.swift
//  Truedata
//

import Foundation

struct BeatListResponse: Decodable {
    var status: Bool
    var message: String
    var data: BeatPaginatedData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(BeatPaginatedData.self, forKey: .data)) ?? BeatPaginatedData()
    }
}

struct BeatPaginatedData: Decodable {
    var currentPage: Int
    var beats: [BeatListItem]
    var lastPage: Int

    enum CodingKeys: String, CodingKey {
        case beats = "data"
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(currentPage: Int = 1, beats: [BeatListItem] = [], lastPage: Int = 1) {
        self.currentPage = currentPage
        self.beats = beats
        self.lastPage = lastPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        beats = (try? container.decode([BeatListItem].self, forKey: .beats)) ?? []
    }

    var hasNextPage: Bool { currentPage < lastPage }
}

struct BeatListItem: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var stateName: String
    var cityName: String
    var status: String
    var isDelete: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case stateName = "state_name"
        case cityName = "city_name"
        case isDelete = "is_delete"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        stateName = container.decodeStringLeniently(forKey: .stateName) ?? ""
        cityName = container.decodeStringLeniently(forKey: .cityName) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? "1"
        isDelete = container.decodeStringLeniently(forKey: .isDelete) ?? "0"
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
        updatedAt = container.decodeStringLeniently(forKey: .updatedAt) ?? ""
    }

    var isActive: Bool { status == "1" }
    var locationText: String { "\(cityName), \(stateName)" }
    var createdDateText: String {
        guard createdAt.count >= 10 else { return createdAt }
        return String(createdAt.prefix(10))
    }
}

struct BeatFormData: Equatable {
    var beatId: String?
    var name: String = ""
    var stateId: String = ""
    var stateName: String = ""
    var cityId: String = ""
    var cityName: String = ""
    var status: String = "1"

    var isEditMode: Bool { beatId != nil }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !stateId.isEmpty
            && !cityId.isEmpty
    }
}

struct BeatStatusMessageResponse: Decodable {
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
