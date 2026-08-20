//
//  CreateOrderModels.swift
//  Truedata
//

import Foundation

struct BrandListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [BrandListItem]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([BrandListItem].self, forKey: .data)) ?? []
    }
}

struct BrandListItem: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var image: String

    enum CodingKeys: String, CodingKey {
        case id, name, image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        image = container.decodeStringLeniently(forKey: .image) ?? ""
    }
}

struct TopSellingProductsSuggestionResponse: Decodable {
    var status: Bool
    var message: String
    var data: [TopSellingProductSuggestion]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([TopSellingProductSuggestion].self, forKey: .data)) ?? []
    }
}

struct TopSellingProductSuggestion: Decodable, Identifiable, Hashable {
    var productName: String
    var productId: String
    var variantId: String
    var productImage: String
    var totalQuantity: Int
    var totalAmount: Double
    var lastOrderedQty: Int

    var id: String { "\(productId)-\(variantId)" }

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productId = "product_id"
        case variantId = "varient_id"
        case productImage = "product_image"
        case totalQuantity = "total_quantity"
        case totalAmount = "total_amount"
        case lastOrderedQty = "last_ordered_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        productId = container.decodeStringLeniently(forKey: .productId) ?? ""
        variantId = container.decodeStringLeniently(forKey: .variantId) ?? ""
        productImage = container.decodeStringLeniently(forKey: .productImage) ?? ""
        totalQuantity = container.decodeIntLeniently(forKey: .totalQuantity)
            ?? Int(container.decodeStringLeniently(forKey: .totalQuantity) ?? "") ?? 0
        totalAmount = Double(container.decodeStringLeniently(forKey: .totalAmount) ?? "")
            ?? container.decodeDoubleLeniently(forKey: .totalAmount) ?? 0
        lastOrderedQty = container.decodeIntLeniently(forKey: .lastOrderedQty)
            ?? Int(container.decodeStringLeniently(forKey: .lastOrderedQty) ?? "") ?? 0
    }
}

struct ActiveProductListResponse: Decodable {
    var status: Bool
    var message: String
    var data: [ActiveProductItem]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([ActiveProductItem].self, forKey: .data)) ?? []
    }
}

struct ActiveProductItem: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var image: String
    var category: String
    var brand: String?
    var status: String
    var price: String?
    var variants: [ActiveProductVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, image, category, brand, status, price
        case variants = "varient"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        image = container.decodeStringLeniently(forKey: .image) ?? ""
        category = container.decodeStringLeniently(forKey: .category) ?? ""
        brand = container.decodeStringLeniently(forKey: .brand)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        price = container.decodeStringLeniently(forKey: .price)
        variants = (try? container.decode([ActiveProductVariant].self, forKey: .variants)) ?? []
    }
}

struct ActiveProductVariant: Decodable, Hashable, Identifiable {
    var id: Int
    var name: String
    var price: String
    var mrp: String
    var ogPrice: String
    var gst: String
    var discountPercentage: Double
    var cgst: Double
    var sgst: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        price = container.decodeStringLeniently(forKey: .price) ?? ""
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        ogPrice = container.decodeStringLeniently(forKey: .ogPrice) ?? ""
        gst = container.decodeStringLeniently(forKey: .gst) ?? ""
        discountPercentage = container.decodeDoubleLeniently(forKey: .discountPercentage) ?? 0
        cgst = container.decodeDoubleLeniently(forKey: .cgst) ?? 0
        sgst = container.decodeDoubleLeniently(forKey: .sgst) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price, mrp, gst, cgst, sgst
        case ogPrice = "og_price"
        case discountPercentage = "discount_percentage"
    }

    var priceValue: Double {
        Double(price) ?? 0
    }

    var mrpValue: Double {
        Double(mrp) ?? 0
    }

    var ogPriceValue: Double {
        Double(ogPrice) ?? priceValue
    }

    var gstLabel: String {
        if let value = Double(gst) {
            return String(format: "%.1f%%", value)
        }
        return gst.isEmpty ? "0%" : "\(gst)%"
    }

    var discountLabel: String {
        "\(Int(discountPercentage.rounded()))% OFF"
    }
}

enum CreateOrderVariantParser {
    static let maxKgsLimit = 10_000_000.0
    static let maxPacketsLimit = 10_000_000

    static func weightInGrams(for variantName: String) -> Double? {
        let cleaned = variantName.lowercased().replacingOccurrences(of: " ", with: "")
        guard let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)") else { return nil }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        guard
            let match = regex.firstMatch(in: cleaned, range: range),
            let valueRange = Range(match.range(at: 1), in: cleaned),
            let value = Double(cleaned[valueRange])
        else { return nil }

        if cleaned.range(of: "kgs?$", options: .regularExpression) != nil
            || cleaned.range(of: "kgs?[^a-z]", options: .regularExpression) != nil {
            return value * 1000
        }

        if cleaned.range(of: "g(?:ms?|rams?)?$", options: .regularExpression) != nil
            || cleaned.range(of: "g(?:ms?|rams?)?[^a-z]", options: .regularExpression) != nil {
            return value
        }

        return nil
    }

    static func formattedKg(quantity: Int, weightInGrams: Double) -> String {
        guard quantity > 0, weightInGrams > 0 else { return "" }
        let kgValue = (Double(quantity) * weightInGrams) / 1000
        if kgValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(kgValue))
        }
        var formatted = String(format: "%.3f", kgValue)
        while formatted.last == "0" { formatted.removeLast() }
        if formatted.last == "." { formatted.removeLast() }
        return formatted
    }

    static func packets(fromKg kg: Double, weightInGrams: Double) -> Int {
        guard kg > 0, weightInGrams > 0 else { return 0 }
        return min(Int((kg * 1000) / weightInGrams), maxPacketsLimit)
    }
}

struct SpecialPriceRequest: Encodable {
    let sallerId: Int
    let staffId: Int
    let productId: Int
    let verientAndPrice: [String: String]
}

struct CreateOrderSubmitLineItem: Identifiable, Hashable {
    var id: String
    var productName: String
    var variantName: String
    var quantity: Int
    var lineTotal: Double
    var gstLabel: String
    var weightKg: Double

    var quantityLabel: String {
        if !variantName.isEmptyString {
            return "\(quantity) pkt X \(variantName)"
        }
        return "\(quantity) pkt"
    }

    var weightLabel: String {
        guard weightKg > 0 else { return "" }
        return String(format: "%.2f kg", weightKg)
    }
}

struct CreateOrderAddCartResponse: Decodable {
    var status: Bool
    var message: String
    var sellerShopName: String
    var sellerAddress: String
    var grandTotal: Double
    var cartLineIds: [Int]
    var submitItems: [CreateOrderSubmitLineItem]
    var syncedItems: [EditOrderLineItem]

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

        if let dataValue = try? container.decode(JSONValue.self, forKey: .data) {
            let parsed = CreateOrderAddCartParser.parse(dataValue)
            sellerShopName = parsed.sellerShopName
            sellerAddress = parsed.sellerAddress
            grandTotal = parsed.grandTotal
            cartLineIds = parsed.cartLineIds
            submitItems = parsed.submitItems
            syncedItems = EditOrderDetailsPayloadParser.parseAddCartResponse(dataValue).items
        } else {
            sellerShopName = ""
            sellerAddress = ""
            grandTotal = 0
            cartLineIds = []
            submitItems = []
            syncedItems = []
        }
    }
}

enum CreateOrderAddCartParser {

    static func parse(_ root: JSONValue) -> (
        sellerShopName: String,
        sellerAddress: String,
        grandTotal: Double,
        cartLineIds: [Int],
        submitItems: [CreateOrderSubmitLineItem]
    ) {
        let dataObject = dataContainer(from: root)
        let grandTotal = dataObject.double(
            for: "totalPriceIncludeGst", "total_price_include_gst",
            "totalPriceWithoutGst", "total_price", "totalPrice", "grand_total"
        )

        guard let cartArray = dataObject["cart"]?.arrayValue, !cartArray.isEmpty else {
            return ("", "", grandTotal, [], [])
        }

        let firstObject = cartArray.first?.objectValue ?? [:]
        let sellerShopName = firstObject.string(for: "seller_shop_name", "sellerShopName", "shop_name")
        let sellerAddress = firstObject.string(for: "seller_address", "sellerAddress", "address")

        var submitItems: [CreateOrderSubmitLineItem] = []
        var cartLineIds: [Int] = []

        for (index, value) in cartArray.enumerated() {
            guard case .object(let object) = value else { continue }

            let productName = object.string(for: "product_name", "productName", "name")
            let variantName = object.string(for: "variant_name", "varient_name", "variantName")
            let qty = object.int(for: "qty", "quantity", "packet", "packets")
            let cartLineId = object.int(for: "cart_id", "cartId", "cart_detail_id")
            if cartLineId > 0 {
                cartLineIds.append(cartLineId)
            }

            let perPrice = object.double(
                for: "perQtyPice", "per_qty_price", "perQtyPrice", "per_price", "price", "og_price"
            )
            let totalPrice = object.double(for: "total_price", "totalPrice", "amount")
            let lineTotal: Double
            if totalPrice > 0 {
                lineTotal = totalPrice
            } else if perPrice > 0, qty > 0 {
                lineTotal = perPrice * Double(qty)
            } else {
                lineTotal = 0
            }

            let gst = object.string(for: "gst", "gst_percentage", "gstPercentage")
            let gstLabel: String
            if gst.isEmptyString {
                gstLabel = ""
            } else if gst.contains("%") {
                gstLabel = gst
            } else {
                gstLabel = "\(gst)% GST"
            }

            var weightKg = 0.0
            if case .object(let weightObject) = object["weight"] {
                weightKg = weightObject.double(for: "kilograms", "kg")
                if weightKg <= 0 {
                    let grams = weightObject.double(for: "grams")
                    if grams > 0 {
                        weightKg = grams / 1000.0
                    }
                }
            }
            if weightKg <= 0 {
                let grams = CreateOrderVariantParser.weightInGrams(for: variantName)
                    ?? CreateOrderVariantParser.weightInGrams(for: productName)
                    ?? 0
                if grams > 0, qty > 0 {
                    weightKg = (grams * Double(qty)) / 1000.0
                }
            }

            guard !productName.isEmptyString || !variantName.isEmptyString else { continue }

            submitItems.append(
                CreateOrderSubmitLineItem(
                    id: "submit-\(index)-\(cartLineId)",
                    productName: productName,
                    variantName: variantName,
                    quantity: qty,
                    lineTotal: lineTotal,
                    gstLabel: gstLabel,
                    weightKg: weightKg
                )
            )
        }

        return (sellerShopName, sellerAddress, grandTotal, cartLineIds, submitItems)
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
