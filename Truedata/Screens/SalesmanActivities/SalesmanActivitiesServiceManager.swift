//
//  SalesmanActivitiesServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class SalesmanActivitiesServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getStaffList() -> AnyPublisher<SalesmanStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func getSalesmanActivities(
        staffId: String,
        startDate: String,
        endDate: String
    ) -> AnyPublisher<SalesmanActivitiesDetailResponse, Error> {
        let params: [String: Any] = [
            "staff_id": staffId,
            "start_date": startDate,
            "end_date": endDate
        ]
        return networkService.request(APIRouter.salesmanActivitiesSummary, params: params, headers: authHeaders)
    }
}
