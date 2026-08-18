//
//  StartNewOrderServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class StartNewOrderServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func getSellersByBeat(beatId: Int) -> AnyPublisher<StartNewOrderSellerListResponse, Error> {
        networkService.request(
            APIRouter.sellerListBeatWise,
            params: ["beat_id": beatId],
            headers: authHeaders
        )
    }

    func setStaffBeat(beatId: Int) -> AnyPublisher<StartNewOrderStatusResponse, Error> {
        networkService.request(
            APIRouter.setStaffBeat,
            params: ["beat_id": beatId],
            headers: authHeaders
        )
    }

    func rearrangeSellers(beatId: Int, sellerIds: [Int]) -> AnyPublisher<StartNewOrderStatusResponse, Error> {
        var params: [String: Any] = ["beat_id": beatId]
        for (index, sellerId) in sellerIds.enumerated() {
            params["seller_id[\(index)]"] = sellerId
            params["priority[\(index)]"] = index + 1
        }
        return networkService.request(
            APIRouter.beatWiseArrangeSellers,
            params: params,
            headers: authHeaders
        )
    }

    func sendOrderApprovalRequest(sellerId: Int) -> AnyPublisher<StartNewOrderStatusResponse, Error> {
        let staffId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = ["seller_id": sellerId]
        if !staffId.isEmptyString { params["staff_id"] = staffId }
        return networkService.request(
            APIRouter.orderApprovalRequest,
            params: params,
            headers: authHeaders
        )
    }

    func submitShopLocationVisited(
        sellerId: String,
        latitude: String,
        longitude: String,
        nextVisitDate: String,
        remark: String,
        address: String,
        imageData: Data
    ) -> AnyPublisher<StartNewOrderStatusResponse, Error> {
        let params: [String: Any] = [
            "seller_id": sellerId,
            "lat": latitude,
            "long": longitude,
            "remark": remark,
            "next_visit_date": nextVisitDate,
            "address": address
        ]

        let file = MultipartFileUpload(
            fieldName: "image",
            fileName: "shop_visit.jpg",
            mimeType: "image/jpeg",
            data: imageData
        )

        return networkService.uploadMultipart(
            APIRouter.shopLocationVisited,
            params: params,
            file: file,
            headers: authHeaders
        )
    }
}
