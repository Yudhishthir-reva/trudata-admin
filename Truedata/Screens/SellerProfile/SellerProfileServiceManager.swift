//
//  SellerProfileServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class SellerProfileServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getSellerProfile(
        sellerId: String,
        startDate: String,
        endDate: String
    ) -> AnyPublisher<SellerProfileResponse, Error> {
        networkService.request(
            APIRouter.sellerProfile2,
            params: [
                "seller_id": sellerId,
                "start_date": startDate,
                "end_date": endDate
            ],
            headers: authHeaders
        )
    }

    func getColorList() -> AnyPublisher<SellerProfileColorListResponse, Error> {
        networkService.request(
            APIRouter.colorList,
            params: [:],
            headers: authHeaders
        )
    }

    func updateSellerColor(sellerId: Int, colorId: Int) -> AnyPublisher<SellerProfileActionResponse, Error> {
        networkService.request(
            APIRouter.updateSellerColor,
            params: [
                "seller_id": sellerId,
                "color_id": colorId
            ],
            headers: authHeaders
        )
    }

    func getSellerOrders(
        sellerId: String,
        page: Int,
        startDate: String,
        endDate: String,
        orderStatus: String,
        orderId: String
    ) -> AnyPublisher<SellerProfileOrderListResponse, Error> {
        var params: [String: Any] = [
            "seller_id": sellerId,
            "page": page,
            "start_date": startDate,
            "date_date": endDate
        ]
        if !orderStatus.isEmptyString { params["order_status"] = orderStatus }
        if !orderId.isEmptyString { params["order_id"] = orderId }
        return networkService.request(APIRouter.sellerOrderList, params: params, headers: authHeaders)
    }

    func getSellerTransactions(
        sellerId: String,
        page: Int,
        startDate: String,
        endDate: String,
        transactionStatus: String,
        transactionId: String
    ) -> AnyPublisher<SellerProfileTransactionListResponse, Error> {
        var params: [String: Any] = [
            "seller_id": sellerId,
            "page": page
        ]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }
        if !transactionStatus.isEmptyString { params["transaction_status"] = transactionStatus }
        if !transactionId.isEmptyString { params["transaction_id"] = transactionId }
        return networkService.request(APIRouter.sellerTransactions, params: params, headers: authHeaders)
    }
}
