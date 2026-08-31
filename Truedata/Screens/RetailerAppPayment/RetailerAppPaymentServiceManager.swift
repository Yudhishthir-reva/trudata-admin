//
//  RetailerAppPaymentServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class RetailerAppPaymentServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchPaymentRequests(
        status: String? = nil,
        sellerId: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        search: String? = nil,
        perPage: Int = 15,
        page: Int = 1
    ) -> AnyPublisher<RetailerPaymentRequestListResponse, Error> {
        var params: [String: Any] = [
            "per_page": perPage,
            "page": page
        ]

        if let status, !status.isEmpty {
            params["status"] = status
        }
        if let sellerId, !sellerId.isEmpty {
            params["seller_id"] = sellerId
        }
        if let startDate, !startDate.isEmpty {
            params["start_date"] = startDate
        }
        if let endDate, !endDate.isEmpty {
            params["end_date"] = endDate
        }
        if let search, !search.trim.isEmpty {
            params["search"] = search.trim
        }

        return networkService.request(
            APIRouter.retailerPaymentRequestList,
            params: params,
            headers: authHeaders
        )
    }

    func updatePaymentStatus(
        id: Int,
        status: String,
        remark: String = ""
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        var params: [String: Any] = [
            "id": id,
            "status": status
        ]
        if !remark.trim.isEmpty {
            params["admin_remark"] = remark.trim
            params["remark"] = remark.trim
            params["reason"] = remark.trim
        }

        return networkService.request(
            APIRouter.updateRetailerPaymentRequest,
            params: params,
            headers: authHeaders
        )
    }

    func fetchSellerList(
        page: Int = 1,
        search: String? = nil
    ) -> AnyPublisher<OrderInsightsSellerListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let search, !search.trim.isEmpty {
            params["shop_name"] = search.trim
            params["search"] = search.trim
        }

        return networkService.request(
            APIRouter.sellerList2,
            params: params,
            headers: authHeaders
        )
    }
}
