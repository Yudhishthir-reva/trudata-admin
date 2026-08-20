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

    func getActiveProducts(
        sellerId: String,
        brandId: Int,
        isEditMode: Bool = false
    ) -> AnyPublisher<ActiveProductListResponse, Error> {
        var params: [String: Any] = [
            "seller_id": sellerId,
            "brand_id": brandId
        ]
        if isEditMode {
            params["is_edit_mode"] = "1"
        }
        return networkService.request(
            APIRouter.productSearchWiseList,
            params: params,
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

    func initCart(sellerId: Int) -> AnyPublisher<InitCartForEditResponse, Error> {
        let staffIdString = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = ["seller_id": sellerId]
        if let staffId = Int(staffIdString), !staffIdString.isEmptyString {
            params["staff_id"] = staffId
        } else if !staffIdString.isEmptyString {
            params["staff_id"] = staffIdString
        }

        return networkService.request(
            APIRouter.addCart,
            params: params,
            headers: authHeaders
        )
    }

    func addCart(cartId: Int, items: [EditOrderLineItem]) -> AnyPublisher<CreateOrderAddCartResponse, Error> {
        networkService.request(
            APIRouter.addCart,
            params: addCartPayload(cartId: cartId, items: items),
            headers: authHeaders
        )
    }

    func submitOrder(
        cartIds: [Int],
        latitude: String,
        longitude: String,
        deliveryDate: String = "",
        discount: Double = 0,
        remark: String = "",
        audioRemark: String = ""
    ) -> AnyPublisher<SellerProfileActionResponse, Error> {
        networkService.request(
            APIRouter.createOrder,
            params: [
                "cart_id": cartIds,
                "delivery_date": deliveryDate,
                "discount": String(format: "%.1f", discount),
                "lat": latitude,
                "lng": longitude,
                "remark": remark,
                "audio_remark": audioRemark
            ],
            headers: authHeaders
        )
    }

    private func addCartPayload(cartId: Int, items: [EditOrderLineItem]) -> [String: Any] {
        let activeItems = items.filter { $0.quantity > 0 && $0.productId > 0 && $0.variantId > 0 }

        var productsById: [Int: [EditOrderLineItem]] = [:]
        for item in activeItems {
            productsById[item.productId, default: []].append(item)
        }

        let products: [[String: Any]] = productsById.keys.sorted().map { productId in
            let variants = (productsById[productId] ?? []).map { item in
                [
                    "variant_id": String(item.variantId),
                    "qty": item.quantity
                ] as [String: Any]
            }
            return [
                "id": String(productId),
                "variants": variants
            ] as [String: Any]
        }

        return [
            "cart_id": String(cartId),
            "items": [
                ["product": products]
            ]
        ]
    }
}
