//
//  OrderApprovalServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class OrderApprovalServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getOrderApprovalList() -> AnyPublisher<OrderApprovalListResponse, Error> {
        networkService.request(APIRouter.orderApprovalRequestList, params: [:], headers: authHeaders)
    }

    func approveRequest(id: Int, status: String = "1") -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "id": id,
            "status": status
        ]
        return networkService.request(APIRouter.updateOrderApprovalRequest, params: params, headers: authHeaders)
    }
}
