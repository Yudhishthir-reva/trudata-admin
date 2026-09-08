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
        startDate: String,
        endDate: String
    ) -> AnyPublisher<DashboardResponse, Error> {
        let params: [String: Any] = [
            "device_id": UserDefaultManager.shared.fcmToken,
            "start_date": startDate,
            "end_date": endDate
        ]
        return networkService.request(
            APIRouter.homeV2,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func loadSubMenu(parentId: Int) -> AnyPublisher<DashboardResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = ["parent_id": parentId]
        if !userId.isEmptyString {
            params["user_id"] = userId
        }
        return networkService.request(
            APIRouter.subMenu,
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
