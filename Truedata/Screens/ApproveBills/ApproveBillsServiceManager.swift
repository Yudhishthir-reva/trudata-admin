//
//  ApproveBillsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class ApproveBillsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getPendingBills() -> AnyPublisher<RiderPendingBillsResponse, Error> {
        networkService.request(APIRouter.pendingBills, params: [:], headers: authHeaders)
    }

    func approveBill(billId: Int, status: Int = 1) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "bill_id": billId,
            "status": status
        ]
        return networkService.request(APIRouter.settlePendingBills, params: params, headers: authHeaders)
    }
}
