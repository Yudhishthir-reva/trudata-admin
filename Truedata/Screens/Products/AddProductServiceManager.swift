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

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchRoles() -> AnyPublisher<StaffRoleResponse, Error> {
        networkService.request(APIRouter.getRoles, params: [:], headers: authHeaders)
    }

    func fetchProductForEdit(productId: Int) -> AnyPublisher<ProductEditResponse, Error> {
        networkService.request(
            APIRouter.productEdit,
            params: ["product_id": productId],
            headers: authHeaders
        )
    }

    func upsertProduct(
        isUpdate: Bool,
        params: [String: Any],
        imageData: Data?,
        otherImages: [Data]
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
        for (index, data) in otherImages.enumerated() {
            files.append(
                MultipartFileUpload(
                    fieldName: "other_images[]",
                    fileName: "product_gallery_\(index).jpg",
                    mimeType: "image/jpeg",
                    data: data
                )
            )
        }
        let router: APIRouter = isUpdate ? .productUpdate : .productSave
        return networkService.uploadMultipart(
            router,
            params: params,
            file: nil,
            files: files,
            headers: authHeaders
        )
    }
}
