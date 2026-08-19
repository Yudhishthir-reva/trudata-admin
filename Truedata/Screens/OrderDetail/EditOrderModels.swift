//
//  EditOrderModels.swift
//  Truedata
//

import Foundation

struct EditOrderLineItem: Identifiable, Hashable {
    var id: String
    var orderItemId: Int
    var cartLineId: Int
    var productId: Int
    var variantId: Int
    var productName: String
    var variantName: String
    var brandName: String
    var productImage: String
    var perPrice: Double
    var quantity: Int

    var lineTotal: Double {
        Double(quantity) * perPrice
    }

    var unitPriceLabel: String {
        let price = perPrice.editOrderPriceLabel
        if variantName.isEmptyString {
            return "₹\(price)/pkt"
        }
        return "\(variantName) - ₹\(price)/pkt"
    }

    static func from(detail: OrderDetailProduct, index: Int) -> EditOrderLineItem {
        EditOrderLineItem(
            id: detail.id.isEmptyString ? "line-\(index)" : detail.id,
            orderItemId: Int(detail.id) ?? 0,
            cartLineId: 0,
            productId: 0,
            variantId: 0,
            productName: detail.productName,
            variantName: detail.variantName,
            brandName: "Spice Monk",
            productImage: detail.productImage,
            perPrice: Double(detail.perPrice) ?? 0,
            quantity: Int(detail.qty) ?? 0
        )
    }

    static func from(
        json: [String: JSONValue],
        fallbackIndex: Int,
        parentProductId: Int = 0,
        parentProductName: String = "",
        parentBrandName: String = "Spice Monk"
    ) -> EditOrderLineItem? {
        var productName = json.string(for: "product_name", "name", "productName")
        if productName.isEmptyString {
            productName = parentProductName
        }

        let variantName = json.string(for: "variant_name", "varient_name", "variantName", "varientName")
        guard !productName.isEmptyString || !variantName.isEmptyString else { return nil }

        if productName.isEmptyString, !variantName.isEmptyString {
            productName = variantName
        }

        let qty = json.int(for: "qty", "quantity", "packet", "packets")
        let perPrice = json.double(
            for: "per_price", "price", "perPrice", "og_price", "ogPrice",
            "general_price", "special_price", "mrp", "retail_price",
            "perQtyPice", "per_qty_price", "perQtyPrice"
        )
        let totalPrice = json.double(for: "total_price", "totalPrice", "amount")
        let resolvedPerPrice: Double
        if perPrice > 0 {
            resolvedPerPrice = perPrice
        } else if qty > 0, totalPrice > 0 {
            resolvedPerPrice = totalPrice / Double(qty)
        } else {
            resolvedPerPrice = 0
        }

        let orderItemId = json.int(for: "order_item_id")
        let cartLineId = EditOrderDetailsPayloadParser.cartLineId(from: json)
        let lineId = json.string(
            for: "order_item_id", "id", "order_detail_id", "cart_detail_id", "line_id"
        )
        let parsedProductId = json.int(for: "product_id", "productId")
        let productId = parsedProductId > 0 ? parsedProductId : parentProductId
        let variantId = json.int(for: "varient_id", "variant_id", "varientId", "variantId")
        let resolvedOrderItemId = orderItemId > 0 ? orderItemId : (Int(lineId) ?? 0)

        return EditOrderLineItem(
            id: lineId.isEmptyString ? "line-\(fallbackIndex)-\(productId)-\(variantId)" : lineId,
            orderItemId: resolvedOrderItemId,
            cartLineId: cartLineId,
            productId: productId,
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            brandName: json.string(for: "brand_name", "brand", "brandName").ifEmpty(default: parentBrandName),
            productImage: json.string(for: "image_url", "product_image", "image", "productImage"),
            perPrice: resolvedPerPrice,
            quantity: qty
        )
    }
}

struct EditOrderDetailsPayload {
    var cartId: Int
    var sellerId: Int
    var numericOrderId: Int
    var sellerShopName: String
    var orderNo: String
    var discount: Double
    var totalPrice: Double
    var brandIds: [Int]
    var items: [EditOrderLineItem]

    var totalItems: Int {
        items.filter { $0.quantity > 0 }.count
    }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    var grandTotal: Double {
        max(subtotal - discount, 0)
    }
}

struct EditOrderDetailsResponse: Decodable {
    var status: Bool
    var message: String
    var payload: EditOrderDetailsPayload

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let dataObject = try? container.decode(JSONValue.self, forKey: .data) {
            payload = EditOrderDetailsPayloadParser.parse(dataObject)
        } else {
            payload = EditOrderDetailsPayload(cartId: 0, sellerId: 0, numericOrderId: 0, sellerShopName: "", orderNo: "", discount: 0, totalPrice: 0, brandIds: [], items: [])
        }
    }
}

struct EditOrderCartSyncResponse: Decodable {
    var status: Bool
    var message: String
    var payload: EditOrderDetailsPayload

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let dataObject = try? container.decode(JSONValue.self, forKey: .data) {
            payload = EditOrderDetailsPayloadParser.parseAddCartResponse(dataObject)
        } else {
            payload = EditOrderDetailsPayload(cartId: 0, sellerId: 0, numericOrderId: 0, sellerShopName: "", orderNo: "", discount: 0, totalPrice: 0, brandIds: [], items: [])
        }
    }
}

struct InitCartForEditResponse: Decodable {
    var status: Bool
    var message: String
    var cartId: Int

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let dataObject = try? container.decode(JSONValue.self, forKey: .data),
           case .object(let object) = dataObject {
            cartId = object.int(for: "cart_id", "cartId")
        } else {
            cartId = 0
        }
    }
}

enum EditOrderDetailsPayloadParser {

    static func cartLineId(from json: [String: JSONValue]) -> Int {
        let cartDetailId = json.int(for: "cart_detail_id", "cartDetailId")
        if cartDetailId > 0 { return cartDetailId }

        let nestedCartId = json.int(for: "cart_id", "cartId")
        if nestedCartId > 0 { return nestedCartId }

        if json.int(for: "order_item_id") == 0 {
            let lineId = json.int(for: "id", "line_id")
            if lineId > 0 { return lineId }
        }

        return 0
    }

    static func parse(_ root: JSONValue) -> EditOrderDetailsPayload {
        let dataObject = dataContainer(from: root)

        let cartId = dataObject.int(for: "cart_id", "cartId")
        let sellerId = dataObject.int(for: "seller_id", "sellerId")
        let numericOrderId = dataObject.int(for: "order_id", "orderId")
        let sellerShopName = dataObject.string(for: "seller_shop_name", "sellerShopName", "shop_name")
        let orderNo = dataObject.string(for: "order_no", "orderNo")
        let discount = dataObject.double(for: "discount", "discount_value", "discountValue")
        let totalPrice = dataObject.double(for: "total_price", "totalPrice", "grand_total", "grandTotal")
        let brandIds = parseBrandIds(from: dataObject)
        let items = parseLineItems(from: dataObject)

        return EditOrderDetailsPayload(
            cartId: cartId,
            sellerId: sellerId,
            numericOrderId: numericOrderId,
            sellerShopName: sellerShopName,
            orderNo: orderNo,
            discount: discount,
            totalPrice: totalPrice,
            brandIds: brandIds,
            items: items
        )
    }

    static func parseAddCartResponse(_ root: JSONValue) -> EditOrderDetailsPayload {
        let dataObject = dataContainer(from: root)

        let totalPrice = dataObject.double(
            for: "totalPriceIncludeGst", "total_price_include_gst",
            "totalPriceWithoutGst", "total_price", "totalPrice", "grand_total"
        )
        let items = parseLineItems(from: dataObject)

        return EditOrderDetailsPayload(
            cartId: 0,
            sellerId: 0,
            numericOrderId: 0,
            sellerShopName: "",
            orderNo: "",
            discount: 0,
            totalPrice: totalPrice,
            brandIds: [],
            items: items
        )
    }

    private static func parseBrandIds(from dataObject: [String: JSONValue]) -> [Int] {
        guard let values = dataObject["brand_ids"]?.arrayValue ?? dataObject["brandIds"]?.arrayValue else {
            return []
        }
        return values.compactMap { value in
            let id = value.intValue
            return id > 0 ? id : nil
        }
    }

    private static func parseLineItems(from dataObject: [String: JSONValue]) -> [EditOrderLineItem] {
        let lineArrays = [
            dataObject["order_details"],
            dataObject["order_detail"],
            dataObject["cart"],
            dataObject["cart_data"],
            dataObject["cart_items"],
            dataObject["items"],
            dataObject["data"]
        ]

        for candidate in lineArrays {
            let array = candidate?.arrayValue ?? []
            guard !array.isEmpty else { continue }

            if let nestedItems = parseNestedOrderDetails(array), !nestedItems.isEmpty {
                return nestedItems
            }

            let flatItems = array.enumerated().compactMap { index, value in
                EditOrderLineItem.from(json: value.objectValue, fallbackIndex: index)
            }
            if !flatItems.isEmpty {
                return flatItems
            }
        }

        return []
    }

    private static func parseNestedOrderDetails(_ orderDetails: [JSONValue]) -> [EditOrderLineItem]? {
        var items: [EditOrderLineItem] = []
        var index = 0

        for detailValue in orderDetails {
            guard case .object(let detailObject) = detailValue else { continue }
            let productId = detailObject.int(for: "id", "product_id", "productId")
            let productName = detailObject.string(for: "product_name", "name", "productName")
            let brandName = detailObject.string(for: "brand_name", "brand", "brandName")

            if let variants = detailObject["variants"]?.arrayValue, !variants.isEmpty {
                for variantValue in variants {
                    guard case .object(let variantObject) = variantValue else { continue }
                    if let item = EditOrderLineItem.from(
                        json: variantObject,
                        fallbackIndex: index,
                        parentProductId: productId,
                        parentProductName: productName,
                        parentBrandName: brandName.ifEmpty(default: "Spice Monk")
                    ) {
                        items.append(item)
                        index += 1
                    }
                }
                continue
            }

            if let item = EditOrderLineItem.from(
                json: detailObject,
                fallbackIndex: index,
                parentProductId: productId,
                parentProductName: productName,
                parentBrandName: brandName.ifEmpty(default: "Spice Monk")
            ) {
                items.append(item)
                index += 1
            }
        }

        return items.isEmpty ? nil : items
    }

    private static func dataContainer(from root: JSONValue) -> [String: JSONValue] {
        guard case .object(let object) = root else { return [:] }
        if let nested = object["data"], case .object(let nestedObject) = nested, !nestedObject.isEmpty {
            return nestedObject
        }
        return object
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(for keys: String...) -> String {
        for key in keys {
            if let value = self[key] {
                let string = value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !string.isEmptyString { return string }
            }
        }
        return ""
    }

    func int(for keys: String...) -> Int {
        for key in keys {
            if let value = self[key] {
                return value.intValue
            }
        }
        return 0
    }

    func double(for keys: String...) -> Double {
        for key in keys {
            if let value = self[key] {
                return value.doubleValue
            }
        }
        return 0
    }
}

private extension String {
    func ifEmpty(default defaultValue: String) -> String {
        isEmptyString ? defaultValue : self
    }
}

extension Double {
    var editOrderPriceLabel: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}
