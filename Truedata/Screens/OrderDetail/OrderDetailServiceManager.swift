//
//  OrderDetailServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class OrderDetailServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getOrderDetail(orderId: String) -> AnyPublisher<OrderDetailResponse, Error> {
        let params: [String: Any] = ["order_id": orderId]
        return networkService.request(APIRouter.orderDetail, params: params, headers: authHeaders)
    }

    func getAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
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

    func updateOrderSeller(orderId: Int, sellerId: Int) -> AnyPublisher<SellerProfileActionResponse, Error> {
        networkService.request(
            APIRouter.updateOrderSeller,
            params: [
                "order_id": orderId,
                "seller_id": sellerId
            ],
            headers: authHeaders
        )
    }

    /// Step 1: Fetch order details for edit (`seller_id` = 0 per Android flow).
    func getOrderDetailsForEdit(orderId: String) -> AnyPublisher<EditOrderDetailsResponse, Error> {
        networkService.request(
            APIRouter.orderDetailsForEdit,
            params: editOrderFetchParams(orderId: orderId),
            headers: authHeaders
        )
    }

    /// Step 2: Initialize edit cart session — returns server-generated `cart_id`.
    func initCartForEdit(orderId: String, sellerId: Int) -> AnyPublisher<InitCartForEditResponse, Error> {
        networkService.request(
            APIRouter.addCartForEdit,
            params: initCartForEditPayload(orderId: orderId, sellerId: sellerId),
            headers: authHeaders
        )
    }

    /// Step 4: Sync cart items with nested product/variants payload.
    func addCartForEdit(
        orderId: String,
        cartId: Int,
        items: [EditOrderLineItem]
    ) -> AnyPublisher<EditOrderCartSyncResponse, Error> {
        networkService.request(
            APIRouter.addCartForEdit,
            params: addCartForEditPayload(orderId: orderId, cartId: cartId, items: items),
            headers: authHeaders
        )
    }

    /// Step 5: Submit edited order.
    func createOrderForEdit(
        orderId: String,
        cartIds: [Int],
        deliveryDate: String,
        discount: Double,
        remark: String = "",
        audioRemark: String = ""
    ) -> AnyPublisher<SellerProfileActionResponse, Error> {
        networkService.request(
            APIRouter.createOrderForEdit,
            params: createOrderForEditPayload(
                orderId: orderId,
                cartIds: cartIds,
                deliveryDate: deliveryDate,
                discount: discount,
                remark: remark,
                audioRemark: audioRemark
            ),
            headers: authHeaders
        )
    }

    private func editOrderFetchParams(orderId: String) -> [String: Any] {
        let staffId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [
            "order_id": orderId,
            "seller_id": 0
        ]
        if !staffId.isEmptyString {
            params["staff_id"] = staffId
        }
        return params
    }

    private func initCartForEditPayload(orderId: String, sellerId: Int) -> [String: Any] {
        let staffIdString = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [
            "seller_id": sellerId,
            "order_id": orderId
        ]
        if let staffId = Int(staffIdString), !staffIdString.isEmptyString {
            params["staff_id"] = staffId
        } else if !staffIdString.isEmptyString {
            params["staff_id"] = staffIdString
        }
        return params
    }

    private func addCartForEditPayload(
        orderId: String,
        cartId: Int,
        items: [EditOrderLineItem]
    ) -> [String: Any] {
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
            "order_id": orderId,
            "items": [
                ["product": products]
            ]
        ]
    }

    private func createOrderForEditPayload(
        orderId: String,
        cartIds: [Int],
        deliveryDate: String,
        discount: Double,
        remark: String,
        audioRemark: String
    ) -> [String: Any] {
        [
            "cart_id": cartIds,
            "order_id": orderId,
            "delivery_date": deliveryDate,
            "discount": discount.editOrderDiscountLabel,
            "remark": remark,
            "audio_remark": audioRemark
        ]
    }

    func cancelOrder(orderId: String) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = ["order_id": orderId]
        return networkService.request(APIRouter.cancelOrder, params: params, headers: authHeaders)
    }
}

private extension Double {
    var editOrderDiscountLabel: String {
        String(format: "%.1f", self)
    }
}
