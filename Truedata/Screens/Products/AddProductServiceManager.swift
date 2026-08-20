//
//  AddProductServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class AddProductServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchBrandsWithCategories() -> AnyPublisher<BrandsWithCategoriesResponse, Error> {
        networkService.request(APIRouter.categoriesWithBrand, params: [:], headers: authHeaders)
    }

    func fetchVariants() -> AnyPublisher<ProductVariantOptionsResponse, Error> {
        networkService.request(APIRouter.getVariant, params: [:], headers: authHeaders)
    }

    func fetchProductForEdit(productId: Int) -> AnyPublisher<ProductEditResponse, Error> {
        networkService.request(
            APIRouter.productEdit,
            params: ["product_id": productId],
            headers: authHeaders
        )
    }

    func saveProduct(
        params: [String: Any],
        imageData: Data?
    ) -> AnyPublisher<ProductStatusMessageResponse, Error> {
        uploadProduct(params: params, imageData: imageData, router: .productSave)
    }

    func updateProduct(
        params: [String: Any],
        imageData: Data?
    ) -> AnyPublisher<ProductStatusMessageResponse, Error> {
        uploadProduct(params: params, imageData: imageData, router: .productUpdate)
    }

    private func uploadProduct(
        params: [String: Any],
        imageData: Data?,
        router: APIRouter
    ) -> AnyPublisher<ProductStatusMessageResponse, Error> {
        var files: [MultipartFileUpload] = []
        if let imageData {
            files.append(
                MultipartFileUpload(
                    fieldName: "image",
                    fileName: "product_image.jpg",
                    mimeType: "image/jpeg",
                    data: imageData
                )
            )
        }
        return networkService.uploadMultipart(
            router,
            params: params,
            file: nil,
            files: files,
            headers: authHeaders
        )
    }
}
