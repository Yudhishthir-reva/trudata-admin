//
//  BeatOrderSummaryServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class BeatOrderSummaryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchSummary(
        startDate: String,
        endDate: String,
        beatId: String,
        staffId: String
    ) -> AnyPublisher<BeatOrderSummaryResponse, Error> {
        var params: [String: Any] = [
            "start_date": startDate,
            "end_date": endDate
        ]
        if !beatId.isEmptyString { params["beat_id"] = beatId }
        if !staffId.isEmptyString { params["staff_id"] = staffId }
        return networkService.request(APIRouter.beatOrderSummary, params: params, headers: authHeaders)
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }
}
