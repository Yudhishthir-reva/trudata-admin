//
//  BeatServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class BeatServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchBeatList(search: String?, page: Int) -> AnyPublisher<BeatListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["search"] = search.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return networkService.request(APIRouter.beatList, params: params, headers: authHeaders)
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func createBeat(
        name: String,
        stateId: String,
        cityId: String,
        status: String
    ) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.createBeat,
            params: [
                "name": name,
                "state_id": stateId,
                "city_id": cityId,
                "status": status
            ],
            headers: authHeaders
        )
    }

    func updateBeat(
        beatId: String,
        name: String,
        stateId: String,
        cityId: String,
        status: String
    ) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.updateBeat,
            params: [
                "beat_id": beatId,
                "name": name,
                "state_id": stateId,
                "city_id": cityId,
                "status": status
            ],
            headers: authHeaders
        )
    }

    func deleteBeat(beatId: String) -> AnyPublisher<BeatStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.deleteBeat,
            params: ["beat_id": beatId],
            headers: authHeaders
        )
    }
}
