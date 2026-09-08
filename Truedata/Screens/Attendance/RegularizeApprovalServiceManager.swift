//
//  RegularizeApprovalServiceManager.swift
//  Truedata
//

import Combine
import Foundation

class RegularizeApprovalServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchRegularizeTeamWiseList() -> AnyPublisher<RegularizeTeamWiseListResponse, Error> {
        networkService.request(APIRouter.regularizeTeamWiseList, params: [:], headers: authHeaders)
    }

    func updateRegularizeStatus(
        regularizeId: Int,
        status: String,
        staffId: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "regularize_id": regularizeId,
            "status": status,
            "staff_id": staffId
        ]
        return networkService.request(APIRouter.updateRegularizeStatus, params: params, headers: authHeaders)
    }
}
