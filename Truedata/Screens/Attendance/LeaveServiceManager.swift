//
//  LeaveServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class LeaveServiceManager {

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

    func fetchLeaveList() -> AnyPublisher<LeaveListResponse, Error> {
        let params: [String: Any] = ["userId": userId]
        return networkService.request(APIRouter.leaveList, params: params, headers: authHeaders)
    }

    func fetchLeaveTypes() -> AnyPublisher<LeaveTypeListResponse, Error> {
        return networkService.request(APIRouter.getLeaveType, params: [:], headers: authHeaders)
    }

    func applyLeave(
        leaveTypeId: Int,
        startDate: String,
        endDate: String,
        remark: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "userId": userId,
            "leave_type": leaveTypeId,
            "start_date": startDate,
            "end_date": endDate,
            "remark": remark
        ]
        return networkService.request(APIRouter.addLeave, params: params, headers: authHeaders)
    }
}
