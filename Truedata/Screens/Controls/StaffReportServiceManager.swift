//
//  StaffReportServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class StaffReportServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchStaffList() -> AnyPublisher<SalesmanStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchTeamAttendance(memberId: Int, month: String) -> AnyPublisher<TeamAttendanceListResponse, Error> {
        let params: [String: Any] = [
            "staff_id": String(memberId),
            "month": month
        ]
        return networkService.request(APIRouter.teamWiseAttendanceList, params: params, headers: authHeaders)
    }

    func fetchTeamLocations(
        memberId: Int,
        date: String,
        page: Int
    ) -> AnyPublisher<StaffLocationListResponse, Error> {
        let params: [String: Any] = [
            "staff_id": String(memberId),
            "date": date,
            "limit": "5",
            "page": String(page)
        ]
        return networkService.request(APIRouter.teamWiseLocationList, params: params, headers: authHeaders)
    }
}
