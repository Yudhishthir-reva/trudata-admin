//
//  StaffActivitiesServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class StaffActivitiesServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchStaffActivitiesHistory(
        startDate: String,
        endDate: String,
        staffName: String,
        page: Int
    ) -> AnyPublisher<StaffActivitiesHistoryResponse, Error> {
        var params: [String: Any] = ["page": page]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }
        if !staffName.isEmptyString { params["staff_name"] = staffName }

        return networkService.request(
            APIRouter.staffActivitiesHistory,
            params: params,
            headers: authHeaders
        )
    }
}
