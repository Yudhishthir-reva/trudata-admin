//
//  AddProductModels.swift
//  Truedata
//

import Foundation

struct ProductEditResponse: Decodable {
    var status: Bool
    var message: String
    var data: ProductEditData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decode(ProductEditData.self, forKey: .data)
    }
}

struct ProductEditData: Decodable {
    var id: Int
    var name: String
    var hsnCode: String
    var description: String
    var categoryId: Int
    var category: String
    var brandId: Int?
    var image: String
    var variants: [ProductEditVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, image
        case hsnCode = "hsn_code"
        case categoryId = "category_id"
        case brandId = "brand_id"
        case variants = "varient"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        hsnCode = container.decodeStringLeniently(forKey: .hsnCode) ?? ""
        description = container.decodeStringLeniently(forKey: .description) ?? ""
        categoryId = container.decodeIntLeniently(forKey: .categoryId) ?? 0
        category = container.decodeStringLeniently(forKey: .category) ?? ""
        brandId = container.decodeIntLeniently(forKey: .brandId)
        image = container.decodeStringLeniently(forKey: .image) ?? ""
        variants = (try? container.decode([ProductEditVariant].self, forKey: .variants)) ?? []
    }
}

struct ProductEditVariant: Decodable {
    var id: Int
    var variantId: String
    var mrp: String
    var retailerPrice: String
    var gst: String
    var name: String
    var availableQuantity: String

    enum CodingKeys: String, CodingKey {
        case id, name, mrp, gst
        case variantId = "varient_id"
        case retailerPrice = "retailer_price"
        case availableQuantity = "avl_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        variantId = container.decodeStringLeniently(forKey: .variantId) ?? ""
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        retailerPrice = container.decodeStringLeniently(forKey: .retailerPrice) ?? ""
        gst = container.decodeStringLeniently(forKey: .gst) ?? "5"
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        availableQuantity = container.decodeStringLeniently(forKey: .availableQuantity) ?? "0"
    }
}

struct BrandsWithCategoriesResponse: Decodable {
    var status: Bool
    var message: String
    var data: [BrandWithCategories]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([BrandWithCategories].self, forKey: .data)) ?? []
    }
}

struct BrandWithCategories: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var categories: [BrandCategoryItem]

    enum CodingKeys: String, CodingKey {
        case id, name, categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        categories = (try? container.decode([BrandCategoryItem].self, forKey: .categories)) ?? []
    }
}

struct BrandCategoryItem: Decodable, Identifiable, Hashable {
    var id: Int
    var brandId: String
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case brandId = "brand_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        brandId = container.decodeStringLeniently(forKey: .brandId) ?? ""
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct ProductVariantOptionsResponse: Decodable {
    var status: Bool
    var message: String
    var data: [ProductVariantOption]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([ProductVariantOption].self, forKey: .data)) ?? []
    }
}

struct ProductVariantOption: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var unitId: String
    var fullName: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case unitId = "unit_id"
        case fullName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        unitId = container.decodeStringLeniently(forKey: .unitId) ?? ""
        fullName = container.decodeStringLeniently(forKey: .fullName) ?? name
    }
}

struct ProductFormVariant: Identifiable, Equatable {
    let id = UUID()
    var variantId: String = ""
    var variantName: String = ""
    var mrp: String = ""
    var retailerPrice: String = ""
    var quantity: String = ""
    var gstRate: String = "5"
}

struct ProductFormErrors {
    var name: String?
    var description: String?
    var hsnCode: String?
    var brand: String?
    var category: String?
    var variants: [UUID: ProductVariantFieldErrors] = [:]
}

struct ProductVariantFieldErrors: Equatable {
    var variant: String?
    var mrp: String?
    var retailerPrice: String?
    var quantity: String?
    var gst: String?
}

enum ProductFormGSTOption: String, CaseIterable, Identifiable {
    case zero = "0"
    case five = "5"
    case twelve = "12"
    case eighteen = "18"
    case twentyEight = "28"

    var id: String { rawValue }

    var label: String { "\(rawValue)%" }
}

extension Notification.Name {
    static let productFormDidSave = Notification.Name("productFormDidSave")
}
