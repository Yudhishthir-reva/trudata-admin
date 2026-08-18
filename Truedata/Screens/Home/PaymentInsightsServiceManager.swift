//
//  PaymentInsightsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class PaymentInsightsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchTransactionHistory(
        page: Int,
        startDate: String,
        endDate: String,
        paymentMode: String,
        paymentStatus: String,
        staffId: String,
        sellerId: String,
        search: String
    ) -> AnyPublisher<PaymentHistoryResponse, Error> {
        var params: [String: Any] = [
            "page": page,
            "start_date": startDate,
            "end_date": endDate
        ]
        if !paymentMode.isEmptyString { params["payment_mode"] = paymentMode }
        if !paymentStatus.isEmptyString { params["payment_status"] = paymentStatus }
        if !staffId.isEmptyString { params["staff_id"] = staffId }
        if !sellerId.isEmptyString { params["seller_id"] = sellerId }
        if !search.isEmptyString { params["search"] = search }

        return networkService.request(
            APIRouter.transactionHistory,
            params: params,
            headers: authHeaders
        )
    }

    func fetchBillSettlementHistory(
        page: Int,
        startDate: String,
        endDate: String,
        paymentMode: String,
        staffId: String,
        sellerId: String
    ) -> AnyPublisher<BillSettlementHistoryResponse, Error> {
        var params: [String: Any] = [
            "page": page,
            "start_date": startDate,
            "end_date": endDate
        ]
        if !paymentMode.isEmptyString { params["payment_mode"] = paymentMode }
        if !staffId.isEmptyString { params["staff_id"] = staffId }
        if !sellerId.isEmptyString { params["seller_id"] = sellerId }

        return networkService.request(
            APIRouter.billSettlementHistory,
            params: params,
            headers: authHeaders
        )
    }

    func getStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func getSellerList(
        page: Int,
        stateId: String? = nil,
        cityId: String? = nil,
        beatId: String? = nil,
        shopName: String? = nil
    ) -> AnyPublisher<OrderInsightsSellerListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let stateId, !stateId.isEmptyString { params["state_id"] = stateId }
        if let cityId, !cityId.isEmptyString { params["city_id"] = cityId }
        if let beatId, !beatId.isEmptyString { params["beat_id"] = beatId }
        if let shopName, !shopName.isEmptyString { params["shop_name"] = shopName }
        return networkService.request(APIRouter.sellerList2, params: params, headers: authHeaders)
    }

    func getAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }
}
