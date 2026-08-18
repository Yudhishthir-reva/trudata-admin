//
//  OrderInsightsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class OrderInsightsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var orders: [OrderInsightsOrder] = []
    @Published var summary: [OrderInsightsSummaryItem] = []
    @Published var recordsCount = 0
    @Published var totalAmount: Double = 0
    @Published var averageOrderValue: Double = 0
    @Published var topSellerName = ""
    @Published var topStaffName = ""
    @Published var topSellerAmount: Double = 0
    @Published var topStaffAmount: Double = 0
    @Published var totalOrders = 0

    @Published var startDate: String
    @Published var endDate: String
    @Published var orderStatus = "0"
    @Published var searchText = ""
    @Published var viewMode: OrderInsightsViewMode = .list
    @Published var isCreatedOrderHistory = false
    @Published var selectedDatePreset: OrderInsightsDatePreset = .today
    @Published var staffId = ""
    @Published var sellerId = ""
    @Published var beatId = ""
    @Published var outOfRangeIsShow = ""
    @Published var hasRemark = "0"

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var isLoadingStaff = false
    @Published var isLoadingSellers = false
    @Published var isLoadingMoreSellers = false
    @Published var sellerCurrentPage = 1
    @Published var sellerLastPage = 1

    private let service = OrderInsightsServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true

    init(startDate: String? = nil, endDate: String? = nil) {
        let today = OrderInsightsDateFormat.todayString
        if let start = startDate, !start.isEmptyString,
           let end = endDate, !end.isEmptyString {
            self.startDate = OrderInsightsDateFormat.normalizedAPIString(from: start)
            self.endDate = OrderInsightsDateFormat.normalizedAPIString(from: end)
            self.selectedDatePreset = .custom
        } else {
            self.startDate = today
            self.endDate = today
        }
    }

    var screenTitle: String {
        isCreatedOrderHistory ? "Created Order History" : "Order Insights"
    }

    var switchHistoryTitle: String {
        isCreatedOrderHistory
            ? "Switch to General Order History"
            : "Switch to Created Order History"
    }

    var isFilterActive: Bool {
        orderStatus != "0"
            || !staffId.isEmptyString
            || !sellerId.isEmptyString
            || !beatId.isEmptyString
            || selectedDatePreset != .today
            || !outOfRangeIsShow.isEmptyString
            || hasRemark == "1"
    }

    var lastUsedFilterLabel: String {
        if orderStatus == "0" { return "Pending" }
        if orderStatus.isEmptyString { return "All Status" }
        return summary.first(where: { $0.status == orderStatus })?.statusLabel ?? "Custom"
    }

    var allSummary: OrderInsightsSummaryItem? {
        summary.first(where: { $0.status.lowercased() == "all" })
    }

    var statusFilterOptions: [OrderInsightsSummaryItem] {
        summary.filter { $0.status.lowercased() != "all" }
    }

    func initialize() {
        loadSupportData()
        loadOrders(isRefresh: true)
    }

    func loadSupportData() {
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
        errorMessage = nil

        let filterStaffId = staffId.isEmptyString
            ? UserDefaultManager.shared.getUserDefaultsString(key: .userId)
            : staffId

        service.getOrderHistory(
            page: currentPage,
            startDate: startDate,
            endDate: endDate,
            status: isCreatedOrderHistory ? orderStatus : orderStatus,
            staffId: filterStaffId,
            sellerId: sellerId,
            orderId: searchText.trim,
            beatId: beatId,
            outOfRangeIsShow: outOfRangeIsShow,
            hasRemark: hasRemark,
            isCreatedOrderHistory: isCreatedOrderHistory
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

            if response.status || !response.data.ordersPage.orders.isEmpty {
                let pageData = response.data.ordersPage
                let newOrders = pageData.orders

                if isRefresh || self.currentPage == 1 {
                    self.orders = newOrders
                } else {
                    self.orders.append(contentsOf: newOrders)
                }

                self.summary = response.data.summary
                self.recordsCount = response.data.total
                self.averageOrderValue = Double(response.data.averageOrderValue) ?? 0
                self.topSellerName = response.data.topSeller?.name ?? ""
                self.topStaffName = response.data.topStaff?.name ?? ""
                self.topSellerAmount = Double(response.data.topSeller?.amount ?? "0") ?? 0
                self.topStaffAmount = Double(response.data.topStaff?.amount ?? "0") ?? 0

                if let allSummary = self.allSummary {
                    self.totalAmount = allSummary.totalAmount
                    self.totalOrders = allSummary.count
                } else {
                    self.totalOrders = response.data.total
                }

                self.currentPage = pageData.currentPage
                self.canLoadMore = pageData.currentPage < pageData.lastPage
                self.errorMessage = nil
            } else if self.orders.isEmpty {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load orders."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentOrder: OrderInsightsOrder) {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = orders.firstIndex(where: { $0.id == currentOrder.id }) else { return }
        guard index >= orders.count - 3 else { return }

        isLoadingMore = true
        currentPage += 1
        loadOrders(isRefresh: false)
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(text.isEmpty ? 0 : 500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.currentPage = 1
                self?.loadOrders(isRefresh: true)
            }
    }

    func toggleCreatedOrderHistory() {
        isCreatedOrderHistory.toggle()
        if isCreatedOrderHistory {
            orderStatus = ""
        }
        currentPage = 1
        loadOrders(isRefresh: true)
    }

    func applyFilters(_ filters: OrderInsightsAppliedFilters) {
        startDate = filters.startDate
        endDate = filters.endDate
        selectedDatePreset = filters.datePreset
        orderStatus = filters.orderStatus
        staffId = filters.staffId
        sellerId = filters.sellerId
        beatId = filters.beatId
        outOfRangeIsShow = filters.outOfRangeIsShow
        hasRemark = filters.hasRemark
        currentPage = 1
        loadOrders(isRefresh: true)
    }

    func resetToDefaultFilters() {
        let today = OrderInsightsDateFormat.todayString
        startDate = today
        endDate = today
        selectedDatePreset = .today
        orderStatus = "0"
        staffId = ""
        sellerId = ""
        beatId = ""
        outOfRangeIsShow = ""
        hasRemark = "0"
        currentPage = 1
        loadOrders(isRefresh: true)
    }

    func applyLastUsedFilter() {
        applyFilters(
            OrderInsightsAppliedFilters(
                startDate: startDate,
                endDate: endDate,
                datePreset: selectedDatePreset,
                orderStatus: "0",
                staffId: staffId,
                sellerId: sellerId,
                beatId: beatId,
                outOfRangeIsShow: outOfRangeIsShow,
                hasRemark: hasRemark
            )
        )
    }

    func currentAppliedFilters() -> OrderInsightsAppliedFilters {
        OrderInsightsAppliedFilters(
            startDate: startDate,
            endDate: endDate,
            datePreset: selectedDatePreset,
            orderStatus: orderStatus,
            staffId: staffId,
            sellerId: sellerId,
            beatId: beatId,
            outOfRangeIsShow: outOfRangeIsShow,
            hasRemark: hasRemark
        )
    }

    func applyDatePreset(_ preset: OrderInsightsDatePreset) {
        selectedDatePreset = preset
        guard preset != .custom,
              let range = OrderInsightsDatePreset.dateRange(for: preset) else { return }
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

    func loadSellers(isRefresh: Bool, stateId: String? = nil, cityId: String? = nil, beatId: String? = nil, search: String? = nil) {
        if isRefresh {
            sellerCurrentPage = 1
            sellerLastPage = 1
            isLoadingSellers = true
        } else {
            guard sellerCurrentPage < sellerLastPage else { return }
            isLoadingMoreSellers = true
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
