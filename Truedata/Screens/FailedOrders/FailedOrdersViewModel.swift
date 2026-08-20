//
//  FailedOrdersViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class FailedOrdersViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var orders: [FailedOrderItem] = []

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: AchievementHistoryDatePreset = .today
    @Published var sellerId = ""
    @Published var riderId = ""
    @Published var searchText = ""

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var isLoadingStaff = false
    @Published var isLoadingSellers = false
    @Published var isLoadingMoreSellers = false
    @Published var sellerCurrentPage = 1
    @Published var sellerLastPage = 1

    private let service = FailedOrdersServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true

    init() {
        let today = OrderInsightsDateFormat.todayString
        startDate = today
        endDate = today
    }

    var isFilterActive: Bool {
        selectedDatePreset != .today || !sellerId.isEmptyString || !riderId.isEmptyString
    }

    func initialize() {
        loadOrders(isRefresh: true)
        loadStaffList()
        loadAreas()
        loadSellers(isRefresh: true)
    }

    func loadOrders(isRefresh: Bool = false) {
        if isRefresh {
            currentPage = 1
            canLoadMore = true
        }

        isLoading = orders.isEmpty || isRefresh
        if !isRefresh { isLoadingMore = true }
        errorMessage = nil

        service.getFailedOrders(
            page: currentPage,
            startDate: startDate,
            endDate: endDate,
            sellerId: sellerId,
            riderId: riderId,
            orderId: searchText.trim
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.orders.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false

            guard response.status || !response.data.isEmpty else {
                if self.orders.isEmpty {
                    self.errorMessage = response.message.nilIfEmpty ?? "Failed to load orders"
                }
                return
            }

            if isRefresh || self.currentPage == 1 {
                self.orders = response.data
            } else {
                self.orders.append(contentsOf: response.data)
            }

            self.canLoadMore = response.data.count >= 10
            self.errorMessage = nil
        }
        .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentOrder: FailedOrderItem) {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = orders.firstIndex(where: { $0.id == currentOrder.id }) else { return }
        guard index >= orders.count - 3 else { return }

        isLoadingMore = true
        currentPage += 1
        loadOrders(isRefresh: false)
    }

    func updateSearch(_ query: String) {
        searchText = query
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadOrders(isRefresh: true)
            }
    }

    func currentAppliedFilters() -> FailedOrdersAppliedFilters {
        FailedOrdersAppliedFilters(
            startDate: startDate,
            endDate: endDate,
            datePreset: selectedDatePreset,
            sellerId: sellerId,
            riderId: riderId
        )
    }

    func applyFilters(_ filters: FailedOrdersAppliedFilters) {
        startDate = filters.startDate
        endDate = filters.endDate
        selectedDatePreset = filters.datePreset
        sellerId = filters.sellerId
        riderId = filters.riderId
        loadOrders(isRefresh: true)
    }

    func clearFilters() {
        let today = OrderInsightsDateFormat.todayString
        applyFilters(
            FailedOrdersAppliedFilters(
                startDate: today,
                endDate: today,
                datePreset: .today,
                sellerId: "",
                riderId: ""
            )
        )
    }

    func applyDatePreset(_ preset: AchievementHistoryDatePreset) {
        selectedDatePreset = preset
        guard preset != .custom,
              let range = AchievementHistoryDatePreset.dateRange(for: preset) else { return }
        startDate = range.start
        endDate = range.end
    }

    private func loadStaffList() {
        isLoadingStaff = true
        service.getStaffList()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.isLoadingStaff = false } receiveValue: { [weak self] response in
                self?.isLoadingStaff = false
                if response.status {
                    self?.staffList = response.data
                }
            }
            .store(in: &cancellables)
    }

    func loadSellers(isRefresh: Bool, stateId: String? = nil, search: String? = nil) {
        if isRefresh {
            sellerCurrentPage = 1
            sellerLastPage = 1
            isLoadingSellers = true
        } else {
            guard sellerCurrentPage < sellerLastPage else { return }
            isLoadingMoreSellers = true
            sellerCurrentPage += 1
        }

        service.getSellerList(page: sellerCurrentPage, stateId: stateId, shopName: search)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLoadingSellers = false
                self?.isLoadingMoreSellers = false
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingSellers = false
                self.isLoadingMoreSellers = false
                if response.status {
                    if isRefresh {
                        self.sellerList = response.data.sellers
                    } else {
                        self.sellerList.append(contentsOf: response.data.sellers)
                    }
                    self.sellerCurrentPage = response.data.currentPage
                    self.sellerLastPage = response.data.lastPage
                }
            }
            .store(in: &cancellables)
    }

    private func loadAreas() {
        service.getAllAreas()
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status {
                    self?.areaStates = response.states
                }
            }
            .store(in: &cancellables)
    }
}
