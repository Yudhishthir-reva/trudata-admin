//
//  SellerReportServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class SellerReportServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchRegisteredSellers(
        page: Int,
        fromDate: String,
        toDate: String,
        registeredBy: String?,
        beatId: String?,
        search: String?
    ) -> AnyPublisher<SellerReportListResponse, Error> {
        var params: [String: Any] = [
            "page": page,
            "per_page": 10
        ]
        if !fromDate.isEmptyString { params["from_date"] = fromDate }
        if !toDate.isEmptyString { params["to_date"] = toDate }
        if let registeredBy, !registeredBy.isEmptyString { params["registered_by"] = registeredBy }
        if let beatId, !beatId.isEmptyString { params["beat_id"] = beatId }
        if let search, !search.isEmptyString { params["search"] = search }
        return networkService.request(APIRouter.getRegisteredSellers, params: params, headers: authHeaders)
    }

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }
}
