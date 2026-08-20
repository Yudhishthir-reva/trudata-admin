//
//  AssignBeatServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class AssignBeatServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchAssignedBeatList() -> AnyPublisher<AssignedBeatListResponse, Error> {
        networkService.request(APIRouter.assignedBeatList, params: [:], headers: authHeaders)
    }

    func assignBeats(
        staffId: String,
        beatIds: [String],
        status: String = "1"
    ) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.assignBeat,
            params: [
                "staff_id": staffId,
                "status": status,
                "beat_id[]": beatIds
            ],
            headers: authHeaders
        )
    }

    func deleteAssignment(assignId: String) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.assignBeatDelete,
            params: ["assign_id": assignId],
            headers: authHeaders
        )
    }

    func updateAssignmentStatus(assignId: String, status: String) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.assignBeatStatusUpdate,
            params: [
                "assign_id": assignId,
                "status": status
            ],
            headers: authHeaders
        )
    }

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchBeatList(page: Int, search: String?) -> AnyPublisher<BeatListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["search"] = search.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return networkService.request(APIRouter.beatList, params: params, headers: authHeaders)
    }
}
