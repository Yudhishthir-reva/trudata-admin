//
//  LeaveApprovalServiceManager.swift
//  Truedata
//

import Combine
import Foundation

class LeaveApprovalServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchLeaveTeamWiseList() -> AnyPublisher<LeaveTeamWiseListResponse, Error> {
        networkService.request(APIRouter.leaveTeamWiseList, params: [:], headers: authHeaders)
    }

    func updateLeaveStatus(
        leaveId: Int,
        status: String,
        staffId: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "leave_id": leaveId,
            "status": status,
            "staff_id": staffId
        ]
        return networkService.request(APIRouter.updateLeaveStatus, params: params, headers: authHeaders)
    }
}
