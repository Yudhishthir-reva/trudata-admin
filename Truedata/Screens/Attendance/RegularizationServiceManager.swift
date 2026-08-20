//
//  RegularizationServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class RegularizationServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    private var userId: String {
        UserDefaultManager.shared.getUserDefaultsString(key: .userId)
    }

    func fetchRegularizationList() -> AnyPublisher<RegularizationListResponse, Error> {
        let params: [String: Any] = ["userId": userId]
        return networkService.request(APIRouter.regularizeList, params: params, headers: authHeaders)
    }

    func applyRegularization(date: String, remark: String) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "userId": userId,
            "date": date,
            "remark": remark
        ]
        return networkService.request(APIRouter.addRegularize, params: params, headers: authHeaders)
    }
}
