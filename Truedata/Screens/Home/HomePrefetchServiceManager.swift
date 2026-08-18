//
//  HomePrefetchServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class HomePrefetchServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchLocationConfig() -> AnyPublisher<LocationConfigResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return networkService.request(
            APIRouter.locationConfig,
            params: ["user_id": userId],
            headers: authHeaders
        )
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func fetchRoles() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.getRoles, params: [:], headers: authHeaders)
    }

    func fetchSellerTypes() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.getSellerType, params: [:], headers: authHeaders)
    }

    func fetchStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchLeaveTypes() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.getLeaveType, params: [:], headers: authHeaders)
    }

    func fetchSellerList() -> AnyPublisher<HomeSellerListResponse, Error> {
        networkService.request(APIRouter.sellerList, params: [:], headers: authHeaders)
    }

    func fetchTransactionHistory(
        startDate: String,
        endDate: String
    ) -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(
            APIRouter.transactionHistory,
            params: [
                "page": "1",
                "start_date": startDate,
                "end_date": endDate
            ],
            headers: authHeaders
        )
    }

    func fetchBillSettlementHistory(
        startDate: String,
        endDate: String
    ) -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(
            APIRouter.billSettlementHistory,
            params: [
                "page": "1",
                "start_date": startDate,
                "end_date": endDate
            ],
            headers: authHeaders
        )
    }

    func fetchTodayAchievements(
        startDate: String,
        endDate: String
    ) -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(
            APIRouter.todayAchievementsDetails,
            params: [
                "start_date": startDate,
                "end_date": endDate
            ],
            headers: authHeaders
        )
    }

    func fetchCategories() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.getCategory, params: [:], headers: authHeaders)
    }

    func fetchVariants() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.getVariant, params: [:], headers: authHeaders)
    }

    func fetchBrands() -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(APIRouter.brandList, params: [:], headers: authHeaders)
    }

    func fetchTopSellingProducts(
        startDate: String,
        endDate: String
    ) -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(
            APIRouter.allTopSellingProducts,
            params: [
                "start_date": startDate,
                "end_date": endDate,
                "page": "1"
            ],
            headers: authHeaders
        )
    }

    func fetchProducts(page: Int = 1) -> AnyPublisher<HomePrefetchAck, Error> {
        networkService.request(
            APIRouter.productList,
            params: ["page": page],
            headers: authHeaders
        )
    }
}
