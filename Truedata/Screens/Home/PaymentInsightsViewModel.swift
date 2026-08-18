//
//  PaymentInsightsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class PaymentInsightsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isLoadingSettlements = false
    @Published var isLoadingMoreSettlements = false
    @Published var errorMessage: String?
    @Published var settlementErrorMessage: String?

    @Published var transactions: [PaymentTransactionItem] = []
    @Published var settlements: [BillSettlementItem] = []
    @Published var summary: PaymentInsightsSummary?
    @Published var recordsCount = 0
    @Published var searchText = ""
    @Published var viewMode: PaymentInsightsViewMode = .report

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: OrderInsightsDatePreset = .today
    @Published var paymentMode = ""
    @Published var paymentStatus = ""
    @Published var staffId = ""
    @Published var sellerId = ""

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var sellerCurrentPage = 1
    @Published var sellerLastPage = 1

    private let service = PaymentInsightsServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var transactionPage = 1
    private var settlementPage = 1
    private var canLoadMoreTransactions = true
    private var canLoadMoreSettlements = true

    init(
        startDate: String? = nil,
        endDate: String? = nil,
        initialViewMode: PaymentInsightsViewMode = .report,
        datePreset: OrderInsightsDatePreset? = nil,
        paymentStatus: String? = nil
    ) {
        viewMode = initialViewMode

        if let preset = datePreset, let range = OrderInsightsDatePreset.dateRange(for: preset) {
            self.startDate = range.start
            self.endDate = range.end
            self.selectedDatePreset = preset
        } else {
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

        if let paymentStatus, !paymentStatus.isEmptyString {
            self.paymentStatus = paymentStatus
        }
    }

    var isFilterActive: Bool {
        !paymentMode.isEmptyString
            || !paymentStatus.isEmptyString
            || !staffId.isEmptyString
            || !sellerId.isEmptyString
            || selectedDatePreset != .today
    }

    func initialize() {
        loadSupportData()
        refreshAll()
    }

    func refreshAll() {
        loadTransactions(isRefresh: true)
        loadSettlements(isRefresh: true)
    }

    func loadTransactions(isRefresh: Bool = false) {
        if isRefresh {
            transactionPage = 1
            canLoadMoreTransactions = true
        }

        isLoading = transactions.isEmpty || isRefresh
        if !isRefresh { isLoadingMore = true }
        errorMessage = nil

        service.fetchTransactionHistory(
            page: transactionPage,
            startDate: startDate,
            endDate: endDate,
            paymentMode: paymentMode,
            paymentStatus: paymentStatus,
            staffId: staffId,
            sellerId: sellerId,
            search: searchText.trim
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.transactions.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false

            if response.status || !response.page.transactions.isEmpty || response.summary != nil {
                let page = response.page
                let isFirstPage = isRefresh || self.transactionPage == 1
                if isFirstPage {
                    self.transactions = page.transactions
                } else {
                    self.transactions.append(contentsOf: page.transactions)
                }
                if isFirstPage, let summary = response.summary {
                    self.summary = summary
                }
                self.recordsCount = page.total
                self.transactionPage = page.currentPage
                self.canLoadMoreTransactions = page.currentPage < page.lastPage
                self.errorMessage = nil
            } else if self.transactions.isEmpty {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load payment history."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadSettlements(isRefresh: Bool = false) {
        if isRefresh {
            settlementPage = 1
            canLoadMoreSettlements = true
        }

        isLoadingSettlements = settlements.isEmpty || isRefresh
        if !isRefresh { isLoadingMoreSettlements = true }
        settlementErrorMessage = nil

        service.fetchBillSettlementHistory(
            page: settlementPage,
            startDate: startDate,
            endDate: endDate,
            paymentMode: paymentMode,
            staffId: staffId,
            sellerId: sellerId
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoadingSettlements = false
            self.isLoadingMoreSettlements = false
            if case .failure(let error) = completion, self.settlements.isEmpty {
                self.settlementErrorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoadingSettlements = false
            self.isLoadingMoreSettlements = false

            if response.status || !response.page.settlements.isEmpty {
                let page = response.page
                if isRefresh || self.settlementPage == 1 {
                    self.settlements = page.settlements
                } else {
                    self.settlements.append(contentsOf: page.settlements)
                }
                self.settlementPage = page.currentPage
                self.canLoadMoreSettlements = page.currentPage < page.lastPage
                self.settlementErrorMessage = nil
            } else if self.settlements.isEmpty {
                self.settlementErrorMessage = response.message.isEmptyString
                    ? "Failed to load settlements."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadMoreTransactionsIfNeeded(current: PaymentTransactionItem) {
        guard canLoadMoreTransactions, !isLoadingMore, !isLoading else { return }
        guard let index = transactions.firstIndex(of: current) else { return }
        guard index >= transactions.count - 3 else { return }
        isLoadingMore = true
        transactionPage += 1
        loadTransactions(isRefresh: false)
    }

    func loadMoreSettlementsIfNeeded(current: BillSettlementItem) {
        guard canLoadMoreSettlements, !isLoadingMoreSettlements, !isLoadingSettlements else { return }
        guard let index = settlements.firstIndex(of: current) else { return }
        guard index >= settlements.count - 3 else { return }
        isLoadingMoreSettlements = true
        settlementPage += 1
        loadSettlements(isRefresh: false)
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(text.isEmpty ? 0 : 500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.transactionPage = 1
                self?.loadTransactions(isRefresh: true)
            }
    }

    func applyFilters(_ filters: PaymentInsightsAppliedFilters) {
        startDate = filters.startDate
        endDate = filters.endDate
        selectedDatePreset = filters.datePreset
        paymentMode = filters.paymentMode
        paymentStatus = filters.paymentStatus
        staffId = filters.staffId
        sellerId = filters.sellerId
        refreshAll()
    }

    func resetToDefaultFilters() {
        let today = OrderInsightsDateFormat.todayString
        startDate = today
        endDate = today
        selectedDatePreset = .today
        paymentMode = ""
        paymentStatus = ""
        staffId = ""
        sellerId = ""
        refreshAll()
    }

    func currentAppliedFilters() -> PaymentInsightsAppliedFilters {
        PaymentInsightsAppliedFilters(
            startDate: startDate,
            endDate: endDate,
            datePreset: selectedDatePreset,
            paymentMode: paymentMode,
            paymentStatus: paymentStatus,
            staffId: staffId,
            sellerId: sellerId
        )
    }

    private func loadSupportData() {
        service.getStaffList()
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status { self?.staffList = response.data }
            }
            .store(in: &cancellables)

        service.getAreas()
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status { self?.areaStates = response.states }
            }
            .store(in: &cancellables)

        loadSellers(isRefresh: true)
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
}
