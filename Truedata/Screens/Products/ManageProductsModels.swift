//
//  ManageProductsModels.swift
//  Truedata
//

import Foundation

struct ManageProductItem: Identifiable, Decodable {
    var id: Int
    var name: String
    var price: String
    var hsnCode: String
    var status: String
    var description: String
    var category: String
    var image: String
    var variants: [ManageProductVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, price, status, description, category, image
        case hsnCode = "hsn_code"
        case variants = "varient"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        price = container.decodeStringLeniently(forKey: .price) ?? ""
        hsnCode = container.decodeStringLeniently(forKey: .hsnCode) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        description = container.decodeStringLeniently(forKey: .description) ?? ""
        category = container.decodeStringLeniently(forKey: .category) ?? ""
        image = container.decodeStringLeniently(forKey: .image) ?? ""
        variants = (try? container.decode([ManageProductVariant].self, forKey: .variants)) ?? []
    }

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame || status == "1"
    }

    var statusLabel: String {
        isActive ? "Active" : "Inactive"
    }

    var variantCountLabel: String {
        let count = max(variants.count, 1)
        return "\(count) variants available"
    }

    var totalStock: Int {
        variants.reduce(0) { partial, variant in
            partial + (Int(variant.availableQuantity) ?? 0)
        }
    }
}

struct ManageProductVariant: Identifiable, Decodable {
    var id: Int
    var name: String
    var price: String
    var availableQuantity: String

    enum CodingKeys: String, CodingKey {
        case id, name, price
        case availableQuantity = "avl_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        price = container.decodeStringLeniently(forKey: .price) ?? ""
        availableQuantity = container.decodeStringLeniently(forKey: .availableQuantity) ?? "0"
    }

    var stockValue: Int {
        Int(availableQuantity) ?? 0
    }
}

struct ManageProductListResponse: Decodable {
    var status: Bool
    var message: String
    var data: ManageProductPage

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode(ManageProductPage.self, forKey: .data)) ?? ManageProductPage()
    }
}

struct ManageProductPage: Decodable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var nextPageUrl: String?
    var products: [ManageProductItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case nextPageUrl = "next_page_url"
        case products = "data"
    }

    init(
        currentPage: Int = 0,
        lastPage: Int = 0,
        total: Int = 0,
        nextPageUrl: String? = nil,
        products: [ManageProductItem] = []
    ) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.nextPageUrl = nextPageUrl
        self.products = products
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        nextPageUrl = container.decodeStringLeniently(forKey: .nextPageUrl)
        products = (try? container.decode([ManageProductItem].self, forKey: .products)) ?? []
    }
}

struct ManageProductCategoryResponse: Decodable {
    var status: Bool
    var message: String
    var data: [ManageProductCategory]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = (try? container.decode([ManageProductCategory].self, forKey: .data)) ?? []
    }
}

struct ManageProductCategory: Identifiable, Decodable, Hashable {
    var id: Int
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct ProductStatusMessageResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
    }
}

enum ManageProductFilterSection: String, CaseIterable, Identifiable {
    case category = "Category"
    case brand = "Brand"
    case status = "Status"

    var id: String { rawValue }
}
