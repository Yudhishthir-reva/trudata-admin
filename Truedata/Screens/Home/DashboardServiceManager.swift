//
//  DashboardServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class DashboardServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func loadHome(
        deviceId: String,
        startDate: String,
        endDate: String
    ) -> AnyPublisher<DashboardResponse, Error> {
        let params: [String: Any] = [
            "device_id": deviceId,
            "start_date": startDate,
            "end_date": endDate
        ]
        return networkService.request(
            APIRouter.homeV2,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func logout() -> AnyPublisher<StatusMessageResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return networkService.request(
            APIRouter.logout,
            params: ["userId": userId],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
