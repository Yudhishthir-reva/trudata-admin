//
//  ManageProductsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class ManageProductsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchProducts(
        page: Int,
        name: String? = nil,
        brandId: String? = nil,
        status: String? = nil,
        categoryId: String? = nil
    ) -> AnyPublisher<ManageProductListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let name, !name.isEmptyString { params["name"] = name }
        if let brandId, !brandId.isEmptyString { params["brand_id"] = brandId }
        if let status, !status.isEmptyString { params["status"] = status }
        if let categoryId, !categoryId.isEmptyString { params["category_id"] = categoryId }
        return networkService.request(APIRouter.productList, params: params, headers: authHeaders)
    }

    func fetchCategories() -> AnyPublisher<ManageProductCategoryResponse, Error> {
        networkService.request(APIRouter.getCategory, params: [:], headers: authHeaders)
    }

    func fetchBrands() -> AnyPublisher<BrandListResponse, Error> {
        networkService.request(APIRouter.brandList, params: [:], headers: authHeaders)
    }

    func updateProductStatus(productId: Int, status: String) -> AnyPublisher<ProductStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.updateProductStatus,
            params: [
                "product_id": productId,
                "status": status
            ],
            headers: authHeaders
        )
    }
}
