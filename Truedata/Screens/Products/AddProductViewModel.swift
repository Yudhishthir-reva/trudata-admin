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
    @Published var shelfLife = ""
    @Published var isReturnable = false
    @Published var returnableDescription = ""
    @Published var selectedBrandId: Int?
    @Published var selectedBrandName = ""
    @Published var selectedCategoryId: Int?
    @Published var selectedCategoryName = ""
    @Published var productVariants: [ProductFormVariant] = [ProductFormVariant()]
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var imageData: Data?
    @Published var existingImageURL = ""
    @Published var otherPhotoItems: [PhotosPickerItem] = []
    @Published var otherImageData: [Data] = []
    @Published var existingOtherImageURLs: [String] = []
    @Published var selectedStaffIds: Set<String> = []

    @Published var brandsWithCategories: [BrandWithCategories] = []
    @Published var availableCategories: [BrandCategoryItem] = []
    @Published var variantOptions: [ProductVariantOption] = []
    @Published var staffOptions: [ProductStaffOption] = []

    @Published var isLoading = false
    @Published var isLoadingDetail = false
    @Published var isStaffLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var staffError: String?
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

    var otherImageSlotsLeft: Int {
        max(0, ProductFormLimits.maxOtherImages - existingOtherImageURLs.count - otherImageData.count)
    }

    var selectedStaffOptions: [ProductStaffOption] {
        let ordered = staffOptions.filter { selectedStaffIds.contains($0.id) }
        let orphans = selectedStaffIds
            .filter { id in staffOptions.contains(where: { $0.id == id }) == false }
            .map { ProductStaffOption(id: $0, name: "Staff #\($0)", mobile: "") }
        return ordered + orphans
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

        loadStaff()
    }

    func loadStaff() {
        isStaffLoading = true
        staffError = nil

        Publishers.Zip(service.fetchStaffList(), service.fetchRoles())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isStaffLoading = false
                if case .failure(let error) = completion {
                    self.staffError = error.localizedDescription
                }
            } receiveValue: { [weak self] staffResponse, rolesResponse in
                guard let self else { return }
                if staffResponse.status {
                    self.staffOptions = ProductAssignableStaff.options(
                        from: staffResponse.data,
                        roles: rolesResponse.data
                    )
                    self.staffError = nil
                } else {
                    self.staffError = staffResponse.message.isEmptyString
                        ? "Failed to load staff"
                        : staffResponse.message
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

    func loadOtherImages() {
        let items = otherPhotoItems
        guard !items.isEmpty else { return }
        let slots = otherImageSlotsLeft
        guard slots > 0 else {
            otherPhotoItems = []
            return
        }

        Task {
            var loaded: [Data] = []
            for item in items.prefix(slots) {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(PaymentImageCompression.compressJPEG(data))
                }
            }
            await MainActor.run {
                self.otherImageData.append(contentsOf: loaded)
                self.otherPhotoItems = []
            }
        }
    }

    func clearMainImage() {
        selectedPhotoItem = nil
        imageData = nil
        // Keep existingImageURL so edit mode still shows the server cover until a new one is chosen.
        if !isEditMode {
            existingImageURL = ""
        }
    }

    func removeOtherImage(at index: Int) {
        guard otherImageData.indices.contains(index) else { return }
        otherImageData.remove(at: index)
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

    func toggleStaff(_ staffId: String) {
        if selectedStaffIds.contains(staffId) {
            selectedStaffIds.remove(staffId)
        } else {
            selectedStaffIds.insert(staffId)
        }
    }

    func addVariant() {
        guard productVariants.count < ProductFormLimits.maxVariants else { return }
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

        let staffIds = staffOptions.map(\.id).filter { selectedStaffIds.contains($0) }
            + selectedStaffIds.filter { id in staffOptions.contains(where: { $0.id == id }) == false }

        var params: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "category_id": selectedCategoryId ?? 0,
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "hsn_code": hsnCode.trimmingCharacters(in: .whitespacesAndNewlines),
            "brand_id": selectedBrandId ?? 0,
            "shelf_life": shelfLife.trimmingCharacters(in: .whitespacesAndNewlines),
            "is_returnable": isReturnable ? "1" : "0",
            "returnable_description": returnableDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            "user_id[]": staffIds,
            "varient_id[]": productVariants.map(\.variantId),
            "retailer_price[]": productVariants.map { $0.retailerPrice.trimmingCharacters(in: .whitespacesAndNewlines) },
            "customer_price[]": productVariants.map { $0.customerPrice.trimmingCharacters(in: .whitespacesAndNewlines) },
            "mrp[]": productVariants.map { $0.mrp.trimmingCharacters(in: .whitespacesAndNewlines) },
            "gst[]": productVariants.map(\.gstRate),
            "avl_qty[]": productVariants.map { $0.quantity.trimmingCharacters(in: .whitespacesAndNewlines) },
            "min_order_qty[]": productVariants.map { $0.minOrderQty.trimmingCharacters(in: .whitespacesAndNewlines) },
            "max_order_qty[]": productVariants.map { $0.maxOrderQty.trimmingCharacters(in: .whitespacesAndNewlines) },
            "variant_for[]": productVariants.map(\.variantFor.rawValue)
        ]

        if let editProductId {
            params["product_id"] = editProductId
        }

        service.upsertProduct(
            isUpdate: isEditMode,
            params: params,
            imageData: imageData,
            otherImages: otherImageData
        )
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
        shelfLife = data.shelfLife
        isReturnable = data.isReturnable
        returnableDescription = data.returnableDescription
        existingImageURL = data.image
        existingOtherImageURLs = data.otherImageURLs
        selectedStaffIds = Set(data.assignedUserIds)

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
                let minQty = variant.minOrderQty.trimmingCharacters(in: .whitespacesAndNewlines)
                return ProductFormVariant(
                    variantId: variant.variantId,
                    variantName: variant.name,
                    variantFor: VariantAudience.fromAPI(variant.variantFor),
                    mrp: variant.mrp,
                    retailerPrice: variant.retailerPrice,
                    customerPrice: variant.customerPrice,
                    quantity: variant.availableQuantity,
                    gstRate: variant.gst.isEmptyString ? "5" : variant.gst,
                    minOrderQty: minQty.isEmpty ? "1" : minQty,
                    maxOrderQty: variant.maxOrderQty
                )
            }
        }

        pendingEditData = nil
    }

    @discardableResult
    private func validateForm() -> Bool {
        var errors = ProductFormErrors()

        errors.name = validateName(name)
        errors.description = validateDescription(description)
        errors.hsnCode = validateHsnCode(hsnCode)
        errors.shelfLife = validateShelfLife(shelfLife)
        errors.returnableDescription = validateReturnableDescription(returnableDescription)

        if selectedBrandId == nil {
            errors.brand = "Please select a brand."
        }
        if selectedCategoryId == nil {
            errors.category = "Please select a category."
        }

        let duplicateIds = Dictionary(grouping: productVariants.map(\.variantId).filter { !$0.isEmptyString }, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys

        for variant in productVariants {
            var variantErrors = validateVariant(variant)
            if duplicateIds.contains(variant.variantId) {
                variantErrors.variant = "Already added"
            }
            if variantErrors.hasError {
                errors.variants[variant.id] = variantErrors
            }
        }

        validationErrors = errors
        return errors.name == nil
            && errors.description == nil
            && errors.hsnCode == nil
            && errors.shelfLife == nil
            && errors.returnableDescription == nil
            && errors.brand == nil
            && errors.category == nil
            && errors.variants.isEmpty
    }

    private func validateVariant(_ variant: ProductFormVariant) -> ProductVariantFieldErrors {
        let mrp = Double(variant.mrp.replacingOccurrences(of: ",", with: ""))
        let minQty = Int(variant.minOrderQty)

        func price(_ value: String, required: Bool) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = Double(trimmed.replacingOccurrences(of: ",", with: ""))
            if trimmed.isEmpty { return required ? "Required" : nil }
            if amount == nil || (amount ?? 0) <= 0 { return "Enter a valid price" }
            if let mrp, let amount, amount > mrp { return "Can't exceed MRP" }
            return nil
        }

        var errors = ProductVariantFieldErrors()
        if variant.variantId.isEmptyString {
            errors.variant = "Select a variant"
        }
        errors.retailerPrice = price(variant.retailerPrice, required: variant.variantFor.needsRetailerPrice)
        errors.customerPrice = price(variant.customerPrice, required: variant.variantFor.needsCustomerPrice)

        let mrpText = variant.mrp.trimmingCharacters(in: .whitespacesAndNewlines)
        if mrpText.isEmpty {
            errors.mrp = "Required"
        } else if mrp == nil || (mrp ?? 0) <= 0 {
            errors.mrp = "Enter a valid MRP"
        }

        if variant.gstRate.isEmptyString {
            errors.gst = "Required"
        } else if let gst = Double(variant.gstRate), !(0...100).contains(gst) {
            errors.gst = "0 – 100"
        } else if Double(variant.gstRate) == nil {
            errors.gst = "0 – 100"
        }

        let qtyText = variant.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        if qtyText.isEmpty {
            errors.quantity = "Required"
        } else if (Int(qtyText) ?? -1) < 0 {
            errors.quantity = "Whole number"
        }

        let minText = variant.minOrderQty.trimmingCharacters(in: .whitespacesAndNewlines)
        if minText.isEmpty {
            errors.minOrderQty = "Required"
        } else if minQty == nil || (minQty ?? 0) < 1 {
            errors.minOrderQty = "At least 1"
        }

        let maxText = variant.maxOrderQty.trimmingCharacters(in: .whitespacesAndNewlines)
        if !maxText.isEmpty {
            if Int(maxText) == nil {
                errors.maxOrderQty = "Whole number"
            } else if let minQty, Int(maxText)! < minQty {
                errors.maxOrderQty = "Below min"
            }
        }

        return errors
    }

    private func validateName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Product name is required" }
        if trimmed.count < 2 { return "Product name must be at least 2 characters" }
        if trimmed.count > 100 { return "Product name must be less than 100 characters" }
        return nil
    }

    private func validateDescription(_ value: String) -> String? {
        if value.count > ProductFormLimits.maxDescriptionLength {
            return "Description must be under \(ProductFormLimits.maxDescriptionLength) characters"
        }
        return nil
    }

    private func validateHsnCode(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "HSN Code is required" }
        if trimmed.count < 4 { return "HSN Code must be at least 4 characters" }
        if trimmed.count > 8 { return "HSN Code must be less than 8 characters" }
        if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            return "HSN Code must contain only numbers"
        }
        return nil
    }

    private func validateShelfLife(_ value: String) -> String? {
        value.count > 50 ? "Keep it under 50 characters" : nil
    }

    private func validateReturnableDescription(_ value: String) -> String? {
        value.count > 250 ? "Keep it under 250 characters" : nil
    }
}
