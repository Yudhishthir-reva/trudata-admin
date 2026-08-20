//
//  ManageProductsViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ManageProductsViewModel: ObservableObject {

    @Published var products: [ManageProductItem] = []
    @Published var categories: [ManageProductCategory] = []
    @Published var brands: [BrandListItem] = []
    @Published var searchText = ""
    @Published var selectedCategoryId = ""
    @Published var selectedBrandId = ""
    @Published var selectedStatus = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isLoadingCategories = false
    @Published var isLoadingBrands = false
    @Published var isUpdatingStatus = false
    @Published var updatingProductId: Int?
    @Published var errorMessage: String?
    @Published var expandedProductIds: Set<Int> = []

    private let service: ManageProductsServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true

    init(service: ManageProductsServiceManager = ManageProductsServiceManager()) {
        self.service = service
    }

    var hasActiveFilters: Bool {
        !selectedCategoryId.isEmptyString ||
        !selectedBrandId.isEmptyString ||
        !selectedStatus.isEmptyString
    }

    func loadInitial() {
        loadFilterData()
        fetchProducts(reset: true)
    }

    func refresh() {
        fetchProducts(reset: true)
    }

    func onSearchChanged(_ query: String) {
        searchText = query
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchProducts(reset: true)
            }
    }

    func loadMoreIfNeeded(currentProduct: ManageProductItem) {
        guard let last = products.last, last.id == currentProduct.id else { return }
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        fetchProducts(reset: false)
    }

    func applyFilters(categoryId: String, brandId: String, status: String) {
        selectedCategoryId = categoryId
        selectedBrandId = brandId
        selectedStatus = status
        fetchProducts(reset: true)
    }

    func clearFilters() {
        selectedCategoryId = ""
        selectedBrandId = ""
        selectedStatus = ""
        fetchProducts(reset: true)
    }

    func toggleExpanded(_ productId: Int) {
        if expandedProductIds.contains(productId) {
            expandedProductIds.remove(productId)
        } else {
            expandedProductIds.insert(productId)
        }
    }

    func toggleProductStatus(_ product: ManageProductItem, isActive: Bool) {
        guard !isUpdatingStatus else { return }
        let newStatus = isActive ? "1" : "0"
        isUpdatingStatus = true
        updatingProductId = product.id

        service.updateProductStatus(productId: product.id, status: newStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isUpdatingStatus = false
                self.updatingProductId = nil
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    let statusLabel = isActive ? "Active" : "Inactive"
                    if let index = self.products.firstIndex(where: { $0.id == product.id }) {
                        self.products[index].status = statusLabel
                    }
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Unable to update product status."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func loadFilterData() {
        isLoadingCategories = true
        service.fetchCategories()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isLoadingCategories = false
            } receiveValue: { [weak self] response in
                self?.categories = response.data
            }
            .store(in: &cancellables)

        isLoadingBrands = true
        service.fetchBrands()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isLoadingBrands = false
            } receiveValue: { [weak self] response in
                self?.brands = response.data
            }
            .store(in: &cancellables)
    }

    private func fetchProducts(reset: Bool) {
        if reset {
            currentPage = 1
            canLoadMore = true
            isLoading = products.isEmpty
        } else {
            isLoadingMore = true
        }
        errorMessage = nil

        service.fetchProducts(
            page: currentPage,
            name: searchText.isEmptyString ? nil : searchText,
            brandId: selectedBrandId.isEmptyString ? nil : selectedBrandId,
            status: selectedStatus.isEmptyString ? nil : selectedStatus,
            categoryId: selectedCategoryId.isEmptyString ? nil : selectedCategoryId
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status {
                let incoming = response.data.products
                self.products = reset ? incoming : self.products + incoming
                self.canLoadMore = response.data.nextPageUrl != nil &&
                    response.data.currentPage < response.data.lastPage
                if self.canLoadMore {
                    self.currentPage += 1
                }
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Unable to load products."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
