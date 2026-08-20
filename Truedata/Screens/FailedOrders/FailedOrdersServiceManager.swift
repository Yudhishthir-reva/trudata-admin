//
//  FailedOrdersServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class FailedOrdersServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getFailedOrders(
        page: Int,
        startDate: String,
        endDate: String,
        sellerId: String = "",
        riderId: String = "",
        orderId: String = ""
    ) -> AnyPublisher<FailedOrdersResponse, Error> {
        var params: [String: Any] = [
            "start_date": startDate,
            "end_date": endDate,
            "page": page
        ]
        if !sellerId.isEmptyString { params["seller_id"] = sellerId }
        if !riderId.isEmptyString { params["rider_id"] = riderId }
        if !orderId.isEmptyString { params["order_id"] = orderId }

        return networkService.request(APIRouter.orderNotDeliveredHistory, params: params, headers: authHeaders)
    }

    func getStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func getSellerList(
        page: Int,
        stateId: String? = nil,
        shopName: String? = nil
    ) -> AnyPublisher<OrderInsightsSellerListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let stateId, !stateId.isEmptyString { params["state_id"] = stateId }
        if let shopName, !shopName.isEmptyString { params["shop_name"] = shopName }
        return networkService.request(APIRouter.sellerList2, params: params, headers: authHeaders)
    }

    func getAllAreas() -> AnyPublisher<OrderInsightsAllAreaResponse, Error> {
        networkService.request(APIRouter.getAllArea, params: [:], headers: authHeaders)
    }
}
