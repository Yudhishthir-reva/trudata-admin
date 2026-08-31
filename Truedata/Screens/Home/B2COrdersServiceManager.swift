//
//  B2COrdersServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class B2COrdersServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getB2COrders(
        status: String = "all",
        page: Int = 1
    ) -> AnyPublisher<B2COrderListResponse, Error> {
        let params: [String: Any] = [
            "status": status.isEmptyString ? "all" : status,
            "page": page
        ]

        return networkService.request(
            APIRouter.b2cOrderList,
            params: params,
            headers: authHeaders
        )
    }

    func getB2COrderDetail(orderId: Int) -> AnyPublisher<B2COrderDetailResponse, Error> {
        let params: [String: Any] = [
            "order_id": orderId
        ]
        return networkService.request(
            APIRouter.b2cOrderDetail,
            params: params,
            headers: authHeaders
        )
    }

    func updateB2COrderStatus(
        orderId: Int,
        status: Int,
        reason: String = ""
    ) -> AnyPublisher<B2COrderStatusUpdateResponse, Error> {
        let params: [String: Any] = [
            "order_id": orderId,
            "status": status,
            "reason": reason
        ]
        return networkService.request(
            APIRouter.b2cOrderStatusUpdate,
            params: params,
            headers: authHeaders
        )
    }
}
