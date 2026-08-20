//
//  LoginRequestsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class LoginRequestsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getDeviceChangeRequests(status: String) -> AnyPublisher<DeviceChangeRequestListResponse, Error> {
        let params: [String: Any] = ["status": status]
        return networkService.request(APIRouter.deviceChangeRequestsList, params: params, headers: authHeaders)
    }

    func approveOrRejectRequest(requestId: Int, status: String) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "request_id": requestId,
            "status": status
        ]
        return networkService.request(APIRouter.approveDeviceChange, params: params, headers: authHeaders)
    }

    func getDeviceChangeHistory(userId: String) -> AnyPublisher<DeviceChangeHistoryResponse, Error> {
        let params: [String: Any] = ["user_id": userId]
        return networkService.request(APIRouter.deviceChangeHistory, params: params, headers: authHeaders)
    }

    func getStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }
}
