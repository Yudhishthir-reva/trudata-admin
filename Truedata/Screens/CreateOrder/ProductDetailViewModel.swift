//
//  ProductDetailViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class ProductDetailViewModel: ObservableObject {

    @Published var product: ActiveProductItem
    @Published private(set) var variantQuantities: [Int: Int] = [:]
    @Published var isSavingSpecialPrices = false
    @Published var specialPriceMessage: String?
    @Published var showSpecialPriceAlert = false

    let brandName: String
    let sellerId: Int
    let brandId: Int

    private let service: CreateOrderServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(
        product: ActiveProductItem,
        brandName: String,
        sellerId: Int,
        brandId: Int,
        service: CreateOrderServiceManager = CreateOrderServiceManager()
    ) {
        self.product = product
        self.brandName = brandName
        self.sellerId = sellerId
        self.brandId = brandId
        self.service = service
    }

    func quantity(for variantID: Int) -> Int {
        variantQuantities[variantID] ?? 0
    }

    func updateQuantity(for variantID: Int, quantity: Int) {
        let clamped = max(0, min(quantity, CreateOrderVariantParser.maxPacketsLimit))
        var updated = variantQuantities
        if clamped == 0 {
            updated.removeValue(forKey: variantID)
        } else {
            updated[variantID] = clamped
        }
        variantQuantities = updated
    }

    var categoryBrandLabel: String {
        if brandName.isEmpty {
            return product.category
        }
        return "\(product.category) • \(brandName)"
    }

    func saveSpecialPrices(_ prices: [Int: String], onSuccess: @escaping () -> Void) {
        let filtered = prices.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filtered.isEmpty else {
            specialPriceMessage = "Please enter at least one special price."
            showSpecialPriceAlert = true
            return
        }

        isSavingSpecialPrices = true

        service.addProductSpecialPrice(
            sellerId: sellerId,
            productId: product.id,
            variantPrices: filtered
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSavingSpecialPrices = false
            if case .failure(let error) = completion {
                self.specialPriceMessage = error.localizedDescription
                self.showSpecialPriceAlert = true
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSavingSpecialPrices = false
            if response.status {
                self.reloadProduct()
                self.specialPriceMessage = response.message.isEmpty ? "Special prices updated." : response.message
                self.showSpecialPriceAlert = true
                onSuccess()
            } else {
                self.specialPriceMessage = response.message.isEmpty ? "Failed to update special prices." : response.message
                self.showSpecialPriceAlert = true
            }
        }
        .store(in: &cancellables)
    }

    private func reloadProduct() {
        service.getActiveProducts(sellerId: String(sellerId), brandId: brandId)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, response.status else { return }
                if let updated = response.data.first(where: { $0.id == self.product.id }) {
                    self.product = updated
                }
            }
            .store(in: &cancellables)
    }
}
