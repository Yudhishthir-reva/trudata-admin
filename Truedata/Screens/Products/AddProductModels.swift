//
//  AddProductModels.swift
//  Truedata
//
//  Matches Android ProductUpsertRequest / ProductEditResponseDto (B2B–B2C rewrite).
//

import Foundation

// MARK: - Variant audience (sold to)

enum VariantAudience: String, CaseIterable, Identifiable, Equatable, Hashable {
    case both = "Both"
    case b2b = "B2B"
    case b2c = "B2C"

    var id: String { rawValue }
    var label: String { rawValue }

    /// Retailers buy this variant → retailer price required.
    var needsRetailerPrice: Bool { self != .b2c }

    /// Consumers buy this variant → customer price required.
    var needsCustomerPrice: Bool { self != .b2b }

    static func fromAPI(_ value: String?) -> VariantAudience {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return VariantAudience(rawValue: trimmed)
            ?? VariantAudience.allCases.first { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }
            ?? .both
    }
}

// MARK: - Edit response

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
    var shelfLife: String
    var isReturnable: Bool
    var returnableDescription: String
    var variants: [ProductEditVariant]
    var otherImageURLs: [String]
    var assignedUserIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, image
        case hsnCode = "hsn_code"
        case categoryId = "category_id"
        case brandId = "brand_id"
        case shelfLife = "shelf_life"
        case isReturnable = "is_returnable"
        case returnableDescription = "returnable_description"
        case varient
        case variants
        case otherImages = "other_images"
        case images
        case productImages = "product_images"
        case userId = "user_id"
        case userIds = "user_ids"
        case users
        case staff
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
        shelfLife = container.decodeStringLeniently(forKey: .shelfLife) ?? ""
        returnableDescription = container.decodeStringLeniently(forKey: .returnableDescription) ?? ""

        if let flag = try? container.decode(JSONValue.self, forKey: .isReturnable) {
            isReturnable = flag.boolValue
        } else {
            let raw = container.decodeStringLeniently(forKey: .isReturnable) ?? ""
            isReturnable = ["1", "true", "yes"].contains(raw.lowercased())
        }

        let legacy = (try? container.decode([ProductEditVariant].self, forKey: .varient)) ?? []
        let modern = (try? container.decode([ProductEditVariant].self, forKey: .variants)) ?? []
        variants = legacy.isEmpty ? modern : legacy

        let imageCandidates: [JSONValue?] = [
            try? container.decode(JSONValue.self, forKey: .otherImages),
            try? container.decode(JSONValue.self, forKey: .images),
            try? container.decode(JSONValue.self, forKey: .productImages)
        ]
        otherImageURLs = imageCandidates
            .compactMap { $0 }
            .map { ProductEditJSONHelpers.imageURLs(from: $0) }
            .first { !$0.isEmpty } ?? []

        let staffCandidates: [JSONValue?] = [
            try? container.decode(JSONValue.self, forKey: .userId),
            try? container.decode(JSONValue.self, forKey: .userIds),
            try? container.decode(JSONValue.self, forKey: .users),
            try? container.decode(JSONValue.self, forKey: .staff)
        ]
        assignedUserIds = staffCandidates
            .compactMap { $0 }
            .map { ProductEditJSONHelpers.ids(from: $0) }
            .first { !$0.isEmpty } ?? []
    }
}

struct ProductEditVariant: Decodable {
    var id: Int
    var variantId: String
    var mrp: String
    var retailerPrice: String
    var customerPrice: String
    var gst: String
    var name: String
    var availableQuantity: String
    var minOrderQty: String
    var maxOrderQty: String
    var variantFor: String

    enum CodingKeys: String, CodingKey {
        case id, name, mrp, gst
        case variantId = "varient_id"
        case retailerPrice = "retailer_price"
        case customerPrice = "customer_price"
        case availableQuantity = "avl_qty"
        case variantName = "variant_name"
        case minOrderQty = "min_order_qty"
        case maxOrderQty = "max_order_qty"
        case variantFor = "variant_for"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        variantId = container.decodeStringLeniently(forKey: .variantId) ?? ""
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        retailerPrice = container.decodeStringLeniently(forKey: .retailerPrice) ?? ""
        customerPrice = container.decodeStringLeniently(forKey: .customerPrice) ?? ""
        gst = container.decodeStringLeniently(forKey: .gst) ?? "5"
        let legacyName = container.decodeStringLeniently(forKey: .name) ?? ""
        let modernName = container.decodeStringLeniently(forKey: .variantName) ?? ""
        name = modernName.isEmptyString ? legacyName : modernName
        availableQuantity = container.decodeStringLeniently(forKey: .availableQuantity) ?? "0"
        minOrderQty = container.decodeStringLeniently(forKey: .minOrderQty) ?? "1"
        maxOrderQty = container.decodeStringLeniently(forKey: .maxOrderQty) ?? ""
        variantFor = container.decodeStringLeniently(forKey: .variantFor) ?? "Both"
    }
}

enum ProductEditJSONHelpers {
    private static let imageKeys = ["image", "url", "image_url", "path", "other_image", "file"]
    private static let idKeys = ["user_id", "staff_id", "id"]

    static func imageURLs(from value: JSONValue) -> [String] {
        flatten(value) { object in
            imageKeys.lazy.compactMap { key -> String? in
                let text = object[key]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return text.isEmpty || text == "null" ? nil : text
            }.first
        }
    }

    static func ids(from value: JSONValue) -> [String] {
        flatten(value) { object in
            idKeys.lazy.compactMap { key -> String? in
                let text = object[key]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return text.isEmpty || text == "null" ? nil : text
            }.first
        }
    }

    private static func flatten(_ value: JSONValue, pick: ([String: JSONValue]) -> String?) -> [String] {
        switch value {
        case .array(let items):
            return items.flatMap { flatten($0, pick: pick) }
        case .object(let object):
            return pick(object).map { [$0] } ?? []
        case .null:
            return []
        default:
            let text = value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("["),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) {
                return flatten(decoded, pick: pick)
            }
            return text
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "null" }
        }
    }
}

// MARK: - Dropdown data

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

// MARK: - Form models

struct ProductStaffOption: Identifiable, Hashable {
    let id: String
    let name: String
    let mobile: String
}

struct ProductFormVariant: Identifiable, Equatable {
    let id = UUID()
    var variantId: String = ""
    var variantName: String = ""
    var variantFor: VariantAudience = .both
    var mrp: String = ""
    var retailerPrice: String = ""
    var customerPrice: String = ""
    var quantity: String = ""
    var gstRate: String = "5"
    var minOrderQty: String = "1"
    var maxOrderQty: String = ""
}

struct ProductFormErrors {
    var name: String?
    var description: String?
    var hsnCode: String?
    var shelfLife: String?
    var returnableDescription: String?
    var brand: String?
    var category: String?
    var variants: [UUID: ProductVariantFieldErrors] = [:]
}

struct ProductVariantFieldErrors: Equatable {
    var variant: String?
    var mrp: String?
    var retailerPrice: String?
    var customerPrice: String?
    var quantity: String?
    var gst: String?
    var minOrderQty: String?
    var maxOrderQty: String?

    var hasError: Bool {
        [variant, mrp, retailerPrice, customerPrice, quantity, gst, minOrderQty, maxOrderQty]
            .contains { $0 != nil }
    }
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

enum ProductFormLimits {
    static let maxVariants = 10
    static let maxOtherImages = 6
    static let maxDescriptionLength = 5000
    static let shelfLifeSuggestions = [
        "3 months", "6 months", "9 months", "12 months", "18 months", "24 months"
    ]
}

/// Sale-person role id used when assigning products (Android `ASSIGNABLE_STAFF_ROLE_ID`).
enum ProductAssignableStaff {
    static let roleId = "3"

    static func options(
        from staff: [RegisteredStaffMember],
        roles: [StaffRoleItem]
    ) -> [ProductStaffOption] {
        let roleName = roles.first { String($0.id) == roleId }?.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return staff
            .filter { member in
                let role = member.roleId.trimmingCharacters(in: .whitespacesAndNewlines)
                if role == roleId { return true }
                if let roleName, !roleName.isEmpty {
                    return role.caseInsensitiveCompare(roleName) == .orderedSame
                }
                return false
            }
            .map {
                ProductStaffOption(
                    id: String($0.id),
                    name: $0.name.isEmptyString ? "Staff #\($0.id)" : $0.name,
                    mobile: $0.mobile
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

extension Notification.Name {
    static let productFormDidSave = Notification.Name("productFormDidSave")
}
