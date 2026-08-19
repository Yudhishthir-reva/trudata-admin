//
//  BrandProductListViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class BrandProductListViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var products: [ActiveProductItem] = []
    @Published var searchQuery = ""

    let brandName: String
    let sellerId: Int
    let brandId: Int
    let isEditMode: Bool

    private let sellerIdString: String
    private let service: CreateOrderServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(
        sellerId: Int,
        brandId: Int,
        brandName: String,
        isEditMode: Bool = false,
        service: CreateOrderServiceManager = CreateOrderServiceManager()
    ) {
        self.sellerId = sellerId
        self.brandId = brandId
        self.brandName = brandName
        self.isEditMode = isEditMode
        self.sellerIdString = String(sellerId)
        self.service = service
    }

    var filteredProducts: [ActiveProductItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var searchPlaceholder: String {
        "Search in \(brandName)..."
    }

    func loadProducts() {
        isLoading = true
        errorMessage = nil

        service.getActiveProducts(sellerId: sellerIdString, brandId: brandId, isEditMode: isEditMode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.products = response.data
                    if self.products.isEmpty {
                        self.errorMessage = "No products in this brand."
                    }
                } else {
                    self.errorMessage = response.message.isEmpty ? "Unable to load products." : response.message
                }
            }
            .store(in: &cancellables)
    }
}
