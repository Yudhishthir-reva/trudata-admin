//
//  OrderInsightsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class OrderInsightsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getOrderHistory(
        page: Int,
        startDate: String,
        endDate: String,
        status: String,
        staffId: String,
        sellerId: String = "",
        riderId: String = "",
        orderId: String = "",
        beatId: String = "",
        outOfRangeIsShow: String = "",
        hasRemark: String = "0",
        isCreatedOrderHistory: Bool = false
    ) -> AnyPublisher<OrderInsightsResponse, Error> {
        var params: [String: Any] = [
            "start_date": startDate,
            "end_date": endDate,
            "has_remark": hasRemark,
            "page": page
        ]
        if !staffId.isEmptyString {
            params["staff_id"] = staffId
        }
        if !status.isEmptyString {
            params["status"] = status
        }
        if !sellerId.isEmptyString {
            params["seller_id"] = sellerId
        }
        if !riderId.isEmptyString {
            params["rider_id"] = riderId
        }
        if !orderId.isEmptyString {
            params["order_id"] = orderId
        }
        if !beatId.isEmptyString {
            params["beat_id"] = beatId
        }
        if !outOfRangeIsShow.isEmptyString {
            params["outOfRangeIsShow"] = outOfRangeIsShow
        }

        let router: APIRouter = isCreatedOrderHistory ? .orderListV3 : .orderListV2
        return networkService.request(router, params: params, headers: authHeaders)
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

    func getAllAreas() -> AnyPublisher<OrderInsightsAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }
}
