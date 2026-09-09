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

    func unassignOrder(orderId: String) -> AnyPublisher<StatusMessageResponse, Error> {
        networkService.request(
            APIRouter.unassignOrder,
            params: ["order_id": orderId],
            headers: authHeaders
        )
    }

    func downloadSettlementReceipt(orderId: String) -> AnyPublisher<Data, Error> {
        downloadPDF(
            router: .paymentReceipt,
            params: ["order_id": orderId]
        )
    }

    private func downloadPDF(
        router: APIRouter,
        params: [String: Any]
    ) -> AnyPublisher<Data, Error> {
        Future { promise in
            guard NetworkMonitor.shared.isConnected else {
                promise(.failure(RequestError.noInternet))
                return
            }

            guard let url = URL(string: router.urlString) else {
                promise(.failure(RequestError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = router.requestType.rawValue
            request.httpBody = Self.urlEncodedBody(from: params)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/pdf", forHTTPHeaderField: "Accept")
            self.authHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error {
                    promise(.failure(error))
                    return
                }

                guard let data, !data.isEmpty else {
                    promise(.failure(RequestError.unknownError))
                    return
                }

                if let pdfData = Self.pdfData(from: data) {
                    promise(.success(pdfData))
                    return
                }

                if let message = Self.errorMessage(from: data) {
                    promise(.failure(RequestError.apiMessage(message)))
                    return
                }

                promise(.failure(RequestError.unknownError))
            }.resume()
        }
        .eraseToAnyPublisher()
    }

    private static func pdfData(from data: Data) -> Data? {
        if isPDFData(data) { return data }

        guard let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmptyString else {
            return nil
        }

        if let hexData = dataFromHexString(string), isPDFData(hexData) {
            return hexData
        }

        return nil
    }

    private static func isPDFData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46
    }

    private static func dataFromHexString(_ hex: String) -> Data? {
        let cleaned = hex
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard cleaned.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard nextIndex <= cleaned.endIndex else { return nil }
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let messages = json["message"] as? [String], let first = messages.first, !first.isEmpty {
            return first
        }
        return nil
    }

    private static func urlEncodedBody(from params: [String: Any]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let pairs = params.map { key, value -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: allowed)
                ?? String(describing: value)
            return "\(encodedKey)=\(encodedValue)"
        }.sorted()
        return Data(pairs.joined(separator: "&").utf8)
    }

    func submitFullReturn(
        orderId: String,
        latitude: String,
        longitude: String,
        remark: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        networkService.request(
            APIRouter.orderReturnFull,
            params: returnOrderBaseParams(
                orderId: orderId,
                latitude: latitude,
                longitude: longitude,
                remark: remark
            ),
            headers: authHeaders
        )
    }

    func submitPartialReturn(
        orderId: String,
        latitude: String,
        longitude: String,
        remark: String,
        items: [(orderItemId: Int, quantity: Int)]
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        var params = returnOrderBaseParams(
            orderId: orderId,
            latitude: latitude,
            longitude: longitude,
            remark: remark
        )
        for (index, item) in items.enumerated() {
            params["order_items_id[\(index)]"] = String(item.orderItemId)
            params["order_items_id_qty[\(index)]"] = String(item.quantity)
        }
        return networkService.request(APIRouter.orderReturnPartial, params: params, headers: authHeaders)
    }

    private func returnOrderBaseParams(
        orderId: String,
        latitude: String,
        longitude: String,
        remark: String
    ) -> [String: Any] {
        let staffId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return [
            "order_id": orderId,
            "staff_id": staffId,
            "lat": latitude,
            "lng": longitude,
            "remark": remark
        ]
    }
}

private extension Double {
    var editOrderDiscountLabel: String {
        String(format: "%.1f", self)
    }
}
