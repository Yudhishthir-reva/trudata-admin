//
//  CreateOrderServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class CreateOrderServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getBrandList() -> AnyPublisher<BrandListResponse, Error> {
        networkService.request(
            APIRouter.brandList,
            params: [:],
            headers: authHeaders
        )
    }

    func getTopSellingSuggestions(sellerId: String) -> AnyPublisher<TopSellingProductsSuggestionResponse, Error> {
        networkService.request(
            APIRouter.topSellingProductsSuggestion,
            params: ["seller_id": sellerId],
            headers: authHeaders
        )
    }

    func getActiveProducts(sellerId: String, brandId: Int) -> AnyPublisher<ActiveProductListResponse, Error> {
        networkService.request(
            APIRouter.productSearchWiseList,
            params: [
                "seller_id": sellerId,
                "brand_id": brandId
            ],
            headers: authHeaders
        )
    }

    func addProductSpecialPrice(
        sellerId: Int,
        productId: Int,
        variantPrices: [Int: String]
    ) -> AnyPublisher<SellerProfileActionResponse, Error> {
        let staffId = Int(UserDefaultManager.shared.getUserDefaultsString(key: .userId)) ?? 0
        let payload = SpecialPriceRequest(
            sallerId: sellerId,
            staffId: staffId,
            productId: productId,
            verientAndPrice: variantPrices.reduce(into: [:]) { result, entry in
                result[String(entry.key)] = entry.value
            }
        )

        guard
            let body = try? JSONEncoder().encode(payload),
            let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else {
            return Fail(error: RequestError.invalidPayloadData).eraseToAnyPublisher()
        }

        return networkService.request(
            APIRouter.addProductSpecialPrice,
            params: jsonObject,
            headers: authHeaders
        )
    }
}
