//
//  OrderDetailServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class OrderDetailServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getOrderDetail(orderId: String) -> AnyPublisher<OrderDetailResponse, Error> {
        let params: [String: Any] = ["order_id": orderId]
        return networkService.request(APIRouter.orderDetail, params: params, headers: authHeaders)
    }
}
