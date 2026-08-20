//
//  AddProductViewModel.swift
//  Truedata
//

import Foundation
import Combine
import PhotosUI
import _PhotosUI_SwiftUI

@MainActor
final class AddProductViewModel: ObservableObject {

    let editProductId: Int?

    @Published var name = ""
    @Published var description = ""
    @Published var hsnCode = ""
    @Published var selectedBrandId: Int?
    @Published var selectedBrandName = ""
    @Published var selectedCategoryId: Int?
    @Published var selectedCategoryName = ""
    @Published var productVariants: [ProductFormVariant] = [ProductFormVariant()]
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var imageData: Data?
    @Published var existingImageURL = ""

    @Published var brandsWithCategories: [BrandWithCategories] = []
    @Published var availableCategories: [BrandCategoryItem] = []
    @Published var variantOptions: [ProductVariantOption] = []

    @Published var isLoading = false
    @Published var isLoadingDetail = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors = ProductFormErrors()
    @Published var showSuccessAlert = false
    @Published var successMessage = ""

    private let service: AddProductServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var pendingEditData: ProductEditData?
    private var isDataLoaded = false

    var isEditMode: Bool { editProductId != nil }

    var screenTitle: String {
        isEditMode ? "Edit Product" : "Add Product"
    }

    var submitButtonTitle: String {
        isEditMode ? "Update Product" : "Save Product"
    }

    init(
        editProductId: Int? = nil,
        service: AddProductServiceManager = AddProductServiceManager()
    ) {
        self.editProductId = editProductId
        self.service = service
    }

    func loadInitialData() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let brandsPublisher = service.fetchBrandsWithCategories()
        let variantsPublisher = service.fetchVariants()

        Publishers.Zip(brandsPublisher, variantsPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] brandsResponse, variantsResponse in
                guard let self else { return }
                self.brandsWithCategories = brandsResponse.data
                self.variantOptions = variantsResponse.data
                self.isDataLoaded = true
                self.applyPendingEditDataIfNeeded()
                if let editProductId = self.editProductId {
                    self.loadProductForEdit(productId: editProductId)
                }
            }
            .store(in: &cancellables)
    }

    func loadSelectedImage() {
        guard let selectedPhotoItem else {
            imageData = nil
            return
        }

        Task {
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.imageData = PaymentImageCompression.compressJPEG(data)
                }
            }
        }
    }

    func clearImage() {
        selectedPhotoItem = nil
        imageData = nil
        existingImageURL = ""
    }

    func selectBrand(_ brand: BrandWithCategories) {
        selectedBrandId = brand.id
        selectedBrandName = brand.name
        availableCategories = brand.categories
        selectedCategoryId = nil
        selectedCategoryName = ""
        validationErrors.brand = nil
        validationErrors.category = nil
    }

    func selectCategory(_ category: BrandCategoryItem) {
        selectedCategoryId = category.id
        selectedCategoryName = category.name
        validationErrors.category = nil
    }

    func addVariant() {
        guard productVariants.count < 10 else { return }
        productVariants.append(ProductFormVariant())
    }

    func removeVariant(at index: Int) {
        guard productVariants.count > 1, productVariants.indices.contains(index) else { return }
        let removed = productVariants.remove(at: index)
        validationErrors.variants.removeValue(forKey: removed.id)
    }

    func updateVariant(_ variant: ProductFormVariant) {
        guard let index = productVariants.firstIndex(where: { $0.id == variant.id }) else { return }
        productVariants[index] = variant
    }

    func selectVariantOption(_ option: ProductVariantOption, for variantId: UUID) {
        guard let index = productVariants.firstIndex(where: { $0.id == variantId }) else { return }
        productVariants[index].variantId = String(option.id)
        productVariants[index].variantName = option.fullName
        validationErrors.variants[variantId]?.variant = nil
    }

    func submit(onSuccess: @escaping () -> Void) {
        guard validateForm() else { return }

        isSubmitting = true
        errorMessage = nil

        var params: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "category_id": selectedCategoryId ?? 0,
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "hsn_code": hsnCode.trimmingCharacters(in: .whitespacesAndNewlines),
            "brand_id": selectedBrandId ?? 0,
            "gst[]": productVariants.map(\.gstRate),
            "mrp[]": productVariants.map(\.mrp),
            "retailer_price[]": productVariants.map(\.retailerPrice),
            "avl_qty[]": productVariants.map(\.quantity),
            "varient_id[]": productVariants.map(\.variantId)
        ]

        if let editProductId {
            params["product_id"] = editProductId
        }

        let publisher: AnyPublisher<ProductStatusMessageResponse, Error>
        if isEditMode {
            publisher = service.updateProduct(params: params, imageData: imageData)
        } else {
            publisher = service.saveProduct(params: params, imageData: imageData)
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSubmitting = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    NotificationCenter.default.post(name: .productFormDidSave, object: nil)
                    self.successMessage = response.message.isEmptyString
                        ? (self.isEditMode ? "Product updated successfully." : "Product added successfully.")
                        : response.message
                    self.showSuccessAlert = true
                    onSuccess()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Unable to save product."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func loadProductForEdit(productId: Int) {
        isLoadingDetail = true
        errorMessage = nil

        service.fetchProductForEdit(productId: productId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingDetail = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if let data = response.data {
                    self.pendingEditData = data
                    self.applyPendingEditDataIfNeeded()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Product data not found."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func applyPendingEditDataIfNeeded() {
        guard isDataLoaded, let data = pendingEditData else { return }

        name = data.name
        description = data.description
        hsnCode = data.hsnCode
        existingImageURL = data.image

        if let brandId = data.brandId,
           let brand = brandsWithCategories.first(where: { $0.id == brandId }) {
            selectedBrandId = brand.id
            selectedBrandName = brand.name
            availableCategories = brand.categories
        }

        selectedCategoryId = data.categoryId
        selectedCategoryName = data.category

        if data.variants.isEmpty {
            productVariants = [ProductFormVariant()]
        } else {
            productVariants = data.variants.map { variant in
                ProductFormVariant(
                    variantId: variant.variantId,
                    variantName: variant.name,
                    mrp: variant.mrp,
                    retailerPrice: variant.retailerPrice,
                    quantity: variant.availableQuantity,
                    gstRate: variant.gst.isEmptyString ? "5" : variant.gst
                )
            }
        }

        pendingEditData = nil
    }

    @discardableResult
    private func validateForm() -> Bool {
        var errors = ProductFormErrors()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.name = "Product name is required."
        }

        let trimmedHSN = hsnCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHSN.isEmpty {
            errors.hsnCode = "HSN code is required."
        }

        if selectedBrandId == nil {
            errors.brand = "Please select a brand."
        }

        if selectedCategoryId == nil {
            errors.category = "Please select a category."
        }

        for variant in productVariants {
            var variantErrors = ProductVariantFieldErrors()
            if variant.variantId.isEmptyString {
                variantErrors.variant = "Please select a variant."
            }
            if variant.mrp.isEmptyString {
                variantErrors.mrp = "MRP is required."
            }
            if variant.retailerPrice.isEmptyString {
                variantErrors.retailerPrice = "Retailer price is required."
            }
            if variant.quantity.isEmptyString {
                variantErrors.quantity = "Quantity is required."
            }
            if variant.gstRate.isEmptyString {
                variantErrors.gst = "GST is required."
            }
            if variantErrors != ProductVariantFieldErrors() {
                errors.variants[variant.id] = variantErrors
            }
        }

        validationErrors = errors
        return errors.name == nil
            && errors.hsnCode == nil
            && errors.brand == nil
            && errors.category == nil
            && errors.variants.isEmpty
    }
}
