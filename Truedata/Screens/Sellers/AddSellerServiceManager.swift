//
//  AddSellerServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class AddSellerServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func fetchSellerTypes() -> AnyPublisher<AddSellerTypeResponse, Error> {
        networkService.request(APIRouter.getSellerType, params: [:], headers: authHeaders)
    }

    func fetchStaffList() -> AnyPublisher<AddSellerStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchSellerDetail(sellerId: Int) -> AnyPublisher<SellerDetailResponse, Error> {
        networkService.request(
            APIRouter.sellerDetail,
            params: ["seller_id": sellerId],
            headers: authHeaders
        )
    }

    func addSeller(
        params: [String: Any],
        files: [MultipartFileUpload]
    ) -> AnyPublisher<SellerStatusMessageResponse, Error> {
        networkService.uploadMultipart(
            APIRouter.addSeller,
            params: params,
            file: nil,
            files: files,
            headers: authHeaders
        )
    }

    func updateSeller(
        params: [String: Any]
    ) -> AnyPublisher<SellerStatusMessageResponse, Error> {
        networkService.uploadMultipart(
            APIRouter.updateSeller,
            params: params,
            file: nil,
            files: [],
            headers: authHeaders
        )
    }
}
