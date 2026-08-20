//
//  RegisteredSellersServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class RegisteredSellersServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchSellerList(
        page: Int,
        stateId: String? = nil,
        cityId: String? = nil,
        beatId: String? = nil,
        status: String? = nil,
        shopName: String? = nil
    ) -> AnyPublisher<RegisteredSellerListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let stateId, !stateId.isEmptyString { params["state_id"] = stateId }
        if let cityId, !cityId.isEmptyString { params["city_id"] = cityId }
        if let beatId, !beatId.isEmptyString { params["beat_id"] = beatId }
        if let status, !status.isEmptyString { params["status"] = status }
        if let shopName, !shopName.isEmptyString { params["shop_name"] = shopName }
        return networkService.request(APIRouter.sellerList2, params: params, headers: authHeaders)
    }

    func updateSellerStatus(sellerId: Int, status: Int) -> AnyPublisher<SellerStatusMessageResponse, Error> {
        let params: [String: Any] = [
            "seller_id": sellerId,
            "status": status
        ]
        return networkService.request(APIRouter.updateSellerStatus, params: params, headers: authHeaders)
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }
}
