//
//  RiderInsightsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class RiderInsightsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchRiderHistory(
        startDate: String,
        endDate: String,
        sellerId: String? = nil
    ) -> AnyPublisher<RiderActivityDashboardResponse, Error> {
        var params: [String: Any] = [
            "start_date": startDate,
            "end_date": endDate
        ]
        if let sellerId = sellerId, !sellerId.isEmptyString {
            params["seller_id"] = sellerId
        }

        return networkService.request(APIRouter.riderHistory, params: params, headers: authHeaders)
    }
}
