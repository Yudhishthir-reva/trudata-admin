//
//  TopSellingProductsModels.swift
//  Truedata
//

import Foundation

struct TopSellingProductsListResponse: Decodable {
    var status: Bool
    var message: String
    var data: TopSellingProductsPageData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(TopSellingProductsPageData.self, forKey: .data))
            ?? TopSellingProductsPageData()
    }
}

struct TopSellingProductsPageData: Decodable {
    var currentPage: Int
    var lastPage: Int
    var products: [AllTopSellingProductItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case products = "data"
    }

    init(currentPage: Int = 0, lastPage: Int = 0, products: [AllTopSellingProductItem] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.products = products
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        products = (try? container.decode([AllTopSellingProductItem].self, forKey: .products)) ?? []
    }
}

struct AllTopSellingProductItem: Identifiable, Decodable, Hashable {
    var id: String { "\(name)_\(imageUrl)_\(totalQuantity)_\(totalAmount)" }
    var name: String
    var imageUrl: String
    var totalQuantity: Int
    var totalAmount: Double

    enum CodingKeys: String, CodingKey {
        case name = "product_name"
        case imageUrl = "product_image"
        case totalQuantity = "total_quantity"
        case totalAmount = "total_amount"
    }

    init(
        name: String = "",
        imageUrl: String = "",
        totalQuantity: Int = 0,
        totalAmount: Double = 0
    ) {
        self.name = name
        self.imageUrl = imageUrl
        self.totalQuantity = totalQuantity
        self.totalAmount = totalAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .imageUrl) ?? ""
        totalQuantity = container.decodeIntLeniently(forKey: .totalQuantity)
            ?? Int(container.decodeStringLeniently(forKey: .totalQuantity) ?? "") ?? 0
        totalAmount = container.decodeDoubleLeniently(forKey: .totalAmount)
            ?? Double(container.decodeStringLeniently(forKey: .totalAmount) ?? "") ?? 0
    }
}

enum TopSellingProductsFilterCategory: String, CaseIterable {
    case dateRange = "Date Range"
    case staff = "Staff"
    case seller = "Seller"
}

struct TopSellingProductsAppliedFilters {
    var startDate: String
    var endDate: String
    var datePreset: OrderInsightsDatePreset
    var staffId: String
    var sellerId: String
}

struct TopSellingExcelExportResult {
    let data: Data
    let filename: String
}
