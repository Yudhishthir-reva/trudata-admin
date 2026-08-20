//
//  ProductCatalogueViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ProductCatalogueViewModel: ObservableObject {

    @Published var brands: [BrandListItem] = []
    @Published var selectedBrandId: Int?
    @Published var selectedBrandName = "All Brands"
    @Published var products: [ActiveProductItem] = []
    @Published var searchQuery = ""
    @Published var selectedProductIds: Set<Int> = []
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var errorMessage: String?
    @Published var exportShareURL: URL?
    @Published var exportAlertMessage: String?

    private let service = ProductCatalogueServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var showSearchField: Bool {
        selectedBrandId != nil
    }

    var filteredProducts: [ActiveProductItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(query)
                || product.category.localizedCaseInsensitiveContains(query)
                || (product.brand?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func loadInitial() {
        loadBrands()
        loadProducts()
    }

    func refresh() {
        loadBrands()
        loadProducts()
    }

    func selectBrand(id: Int?, name: String) {
        selectedBrandId = id
        selectedBrandName = name
        searchQuery = ""
        selectedProductIds.removeAll()
        loadProducts()
    }

    func toggleSelection(for productId: Int) {
        if selectedProductIds.contains(productId) {
            selectedProductIds.remove(productId)
        } else {
            selectedProductIds.insert(productId)
        }
    }

    func downloadCatalogPDF() {
        isDownloading = true
        exportAlertMessage = nil

        service.downloadCatalogPDF(brandId: selectedBrandId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isDownloading = false
                if case .failure(let error) = completion {
                    self.exportAlertMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] data in
                guard let self else { return }
                let brandPart = self.selectedBrandName.replacingOccurrences(of: " ", with: "_")
                self.sharePDF(data: data, prefix: "Catalog_\(brandPart)")
            }
            .store(in: &cancellables)
    }

    private func loadBrands() {
        service.fetchBrands()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.brands = response.data
                }
            }
            .store(in: &cancellables)
    }

    private func loadProducts() {
        isLoading = true
        errorMessage = nil

        service.fetchCatalogueProducts(brandId: selectedBrandId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.products = response.data
                    self.errorMessage = response.data.isEmpty ? "No products found in this brand." : nil
                } else {
                    self.products = []
                    self.errorMessage = response.message.isEmpty ? "Unable to load products." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func sharePDF(data: Data, prefix: String) {
        let fileName = "\(prefix)_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            exportShareURL = url
        } catch {
            exportAlertMessage = "Unable to prepare PDF for sharing."
        }
    }
}
