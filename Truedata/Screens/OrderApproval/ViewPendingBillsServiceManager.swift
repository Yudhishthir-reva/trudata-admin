//
//  ViewPendingBillsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class ViewPendingBillsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getPendingPaymentBills(
        sellerId: Int,
        staffId: Int,
        page: Int
    ) -> AnyPublisher<PendingPaymentBillsResponse, Error> {
        let params: [String: Any] = [
            "seller_id": sellerId,
            "staff_id": staffId,
            "page": page
        ]
        return networkService.request(
            APIRouter.viewPendingPaymentBillList,
            params: params,
            headers: authHeaders
        )
    }
}
