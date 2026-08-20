//
//  MyProfileServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class MyProfileServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getLoggedInUserProfile() -> AnyPublisher<MyProfileResponse, Error> {
        networkService.request(APIRouter.loggedInUserProfile, params: [:], headers: authHeaders)
    }

    func logout() -> AnyPublisher<StatusMessageResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return networkService.request(
            APIRouter.logout,
            params: ["userId": userId],
            headers: authHeaders
        )
    }
}
