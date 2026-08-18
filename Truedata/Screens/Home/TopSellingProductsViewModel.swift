//
//  TopSellingProductsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class TopSellingProductsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var products: [AllTopSellingProductItem] = []
    @Published var searchText = ""

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: OrderInsightsDatePreset = .today
    @Published var staffId = ""
    @Published var sellerId: String

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var sellerCurrentPage = 1
    @Published var sellerLastPage = 1
    @Published var isExportingExcel = false
    @Published var excelShareURL: URL?
    @Published var exportAlertMessage: String?

    private let service = TopSellingProductsServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true
    private let lockedSellerId: String

    init(startDate: String? = nil, endDate: String? = nil, sellerId: String = "") {
        let today = OrderInsightsDateFormat.todayString
        lockedSellerId = sellerId

        if let start = startDate, !start.isEmptyString,
           let end = endDate, !end.isEmptyString {
            self.startDate = OrderInsightsDateFormat.normalizedAPIString(from: start)
            self.endDate = OrderInsightsDateFormat.normalizedAPIString(from: end)
            self.selectedDatePreset = .custom
        } else {
            self.startDate = today
            self.endDate = today
        }

        self.sellerId = sellerId
    }

    var isSellerFilterLocked: Bool {
        !lockedSellerId.isEmptyString
    }

    var isFilterActive: Bool {
        !staffId.isEmptyString
            || (!sellerId.isEmptyString && !isSellerFilterLocked)
            || selectedDatePreset != .today
    }

    func initialize() {
        loadSupportData()
        loadProducts(isRefresh: true)
    }

    func loadSupportData() {
        loadStaffList()
        loadAreas()
        loadSellers(isRefresh: true)
    }

    func loadProducts(isRefresh: Bool = false) {
        if isRefresh {
            currentPage = 1
            canLoadMore = true
        }

        isLoading = products.isEmpty || isRefresh
        if !isRefresh { isLoadingMore = true }
        errorMessage = nil

        service.fetchTopSellingProducts(
            page: currentPage,
            startDate: startDate,
            endDate: endDate,
            sellerId: sellerId,
            staffId: staffId,
            searchQuery: searchText.trim
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.products.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false

            if response.status || !response.data.products.isEmpty {
                let pageData = response.data
                if isRefresh || self.currentPage == 1 {
                    self.products = pageData.products
                } else {
                    self.products.append(contentsOf: pageData.products)
                }
                self.currentPage = pageData.currentPage
                self.canLoadMore = pageData.currentPage < pageData.lastPage
                self.errorMessage = nil
            } else if self.products.isEmpty {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load products."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentProduct: AllTopSellingProductItem) {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = products.firstIndex(of: currentProduct) else { return }
        guard index >= products.count - 3 else { return }

        isLoadingMore = true
        currentPage += 1
        loadProducts(isRefresh: false)
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(text.isEmpty ? 0 : 500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.currentPage = 1
                self?.loadProducts(isRefresh: true)
            }
    }

    func applyFilters(_ filters: TopSellingProductsAppliedFilters) {
        startDate = filters.startDate
        endDate = filters.endDate
        selectedDatePreset = filters.datePreset
        staffId = filters.staffId
        if !isSellerFilterLocked {
            sellerId = filters.sellerId
        }
        currentPage = 1
        loadProducts(isRefresh: true)
    }

    func resetToDefaultFilters() {
        let today = OrderInsightsDateFormat.todayString
        startDate = today
        endDate = today
        selectedDatePreset = .today
        staffId = ""
        if !isSellerFilterLocked {
            sellerId = ""
        }
        currentPage = 1
        loadProducts(isRefresh: true)
    }

    func currentAppliedFilters() -> TopSellingProductsAppliedFilters {
        TopSellingProductsAppliedFilters(
            startDate: startDate,
            endDate: endDate,
            datePreset: selectedDatePreset,
            staffId: staffId,
            sellerId: sellerId
        )
    }

    func exportExcel() {
        guard !isExportingExcel else { return }
        isExportingExcel = true
        exportAlertMessage = nil

        service.exportTopSellingProductsExcel(
            startDate: startDate,
            endDate: endDate,
            sellerId: sellerId,
            staffId: staffId
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isExportingExcel = false
            if case .failure(let error) = completion {
                self.exportAlertMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] result in
            guard let self else { return }
            self.isExportingExcel = false
            do {
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(result.filename)
                try result.data.write(to: fileURL, options: .atomic)
                self.excelShareURL = fileURL
            } catch {
                self.exportAlertMessage = "Failed to save Excel file."
            }
        }
        .store(in: &cancellables)
    }

    private func loadStaffList() {
        service.getStaffList()
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status {
                    self?.staffList = response.data
                }
            }
            .store(in: &cancellables)
    }

    func loadSellers(
        isRefresh: Bool,
        stateId: String? = nil,
        cityId: String? = nil,
        beatId: String? = nil,
        search: String? = nil
    ) {
        if isRefresh {
            sellerCurrentPage = 1
            sellerLastPage = 1
        } else {
            guard sellerCurrentPage < sellerLastPage else { return }
            sellerCurrentPage += 1
        }

        service.getSellerList(
            page: sellerCurrentPage,
            stateId: stateId,
            cityId: cityId,
            beatId: beatId,
            shopName: search
        )
        .receive(on: RunLoop.main)
        .sink { _ in } receiveValue: { [weak self] response in
            guard let self, response.status else { return }
            if isRefresh {
                self.sellerList = response.data.sellers
            } else {
                self.sellerList.append(contentsOf: response.data.sellers)
            }
            self.sellerCurrentPage = response.data.currentPage
            self.sellerLastPage = response.data.lastPage
        }
        .store(in: &cancellables)
    }

    private func loadAreas() {
        service.getAreas()
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status {
                    self?.areaStates = response.states
                }
            }
            .store(in: &cancellables)
    }
}
