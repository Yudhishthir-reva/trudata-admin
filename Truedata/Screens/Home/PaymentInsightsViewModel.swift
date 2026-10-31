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
    @Published var settlementRecordsCount = 0
    @Published var searchText = ""
    @Published var viewMode: PaymentInsightsViewMode = .report

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: OrderInsightsDatePreset = .today
    @Published var paymentMode = ""
    @Published var paymentStatus = ""
    @Published var staffId = ""
    @Published var sellerId = ""
    @Published var sellerName = ""

    /// Settlements filter on their own; Report and Bills share the fields above.
    @Published var settlementFilters = PaymentSettlementFilters.today

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var sellerCurrentPage = 1
    @Published var sellerLastPage = 1
    @Published var sellerTotal = 0

    private let service = PaymentInsightsServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    /// One request per list, cancelled on refresh, so a slow response for old filters can't
    /// land after (and overwrite) the one for the filters now showing.
    private var transactionCancellable: AnyCancellable?
    private var settlementCancellable: AnyCancellable?
    private var sellerCancellable: AnyCancellable?
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

        // Settlements open on the same dates the caller asked for (as Android's
        // initializeWithPresets does), then filter independently.
        settlementFilters = PaymentSettlementFilters(
            startDate: self.startDate,
            endDate: self.endDate,
            datePreset: selectedDatePreset
        )
    }

    var reportFilterSummary: (parts: [String], active: Int) {
        let staffName = staffList.first { String($0.id) == staffId }?.name ?? ""
        return PaymentInsightsFilterSummary.parts(for: currentAppliedFilters(), staffName: staffName)
    }

    var settlementFilterSummary: (parts: [String], active: Int) {
        PaymentInsightsFilterSummary.parts(for: settlementFilters)
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
            transactionCancellable?.cancel()
            transactionPage = 1
            canLoadMoreTransactions = true
            isLoadingMore = false
        }
        let requestedPage = transactionPage

        isLoading = transactions.isEmpty || isRefresh
        if !isRefresh { isLoadingMore = true }
        errorMessage = nil

        transactionCancellable = service.fetchTransactionHistory(
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
            guard case .failure(let error) = completion else { return }
            self.stepBackTransactionPage(from: requestedPage, isRefresh: isRefresh)
            if self.transactions.isEmpty {
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
            } else {
                self.stepBackTransactionPage(from: requestedPage, isRefresh: isRefresh)
                if self.transactions.isEmpty {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load payment history."
                        : response.message
                }
            }
        }
    }

    /// A failed next page goes back one, so scrolling again retries it instead of skipping it.
    private func stepBackTransactionPage(from page: Int, isRefresh: Bool) {
        guard !isRefresh, page > 1 else { return }
        transactionPage = page - 1
    }

    func loadSettlements(isRefresh: Bool = false) {
        if isRefresh {
            settlementCancellable?.cancel()
            settlementPage = 1
            canLoadMoreSettlements = true
            isLoadingMoreSettlements = false
        }
        let requestedPage = settlementPage
        let filters = settlementFilters

        isLoadingSettlements = settlements.isEmpty || isRefresh
        if !isRefresh { isLoadingMoreSettlements = true }
        settlementErrorMessage = nil

        settlementCancellable = service.fetchBillSettlementHistory(
            page: settlementPage,
            startDate: filters.startDate,
            endDate: filters.endDate,
            paymentType: filters.paymentType,
            sellerId: filters.sellerId
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoadingSettlements = false
            self.isLoadingMoreSettlements = false
            guard case .failure(let error) = completion else { return }
            self.stepBackSettlementPage(from: requestedPage, isRefresh: isRefresh)
            if self.settlements.isEmpty {
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
                self.settlementRecordsCount = page.total
                self.settlementPage = page.currentPage
                self.canLoadMoreSettlements = page.currentPage < page.lastPage
                self.settlementErrorMessage = nil
            } else {
                self.stepBackSettlementPage(from: requestedPage, isRefresh: isRefresh)
                if self.settlements.isEmpty {
                    self.settlementErrorMessage = response.message.isEmptyString
                        ? "Failed to load settlements."
                        : response.message
                }
            }
        }
    }

    private func stepBackSettlementPage(from page: Int, isRefresh: Bool) {
        guard !isRefresh, page > 1 else { return }
        settlementPage = page - 1
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

    /// Report and Bills only (they come from one API); Settlements keeps its own filters.
    func applyFilters(_ filters: PaymentInsightsAppliedFilters) {
        startDate = filters.startDate
        endDate = filters.endDate
        selectedDatePreset = filters.datePreset
        paymentMode = filters.paymentMode
        paymentStatus = filters.paymentStatus
        staffId = filters.staffId
        sellerId = filters.sellerId
        sellerName = filters.sellerId.isEmptyString ? "" : filters.sellerName
        loadTransactions(isRefresh: true)
    }

    /// Report and Bills back to today with no other filter; Settlements untouched.
    func resetToDefaultFilters() {
        let today = OrderInsightsDateFormat.todayString
        startDate = today
        endDate = today
        selectedDatePreset = .today
        paymentMode = ""
        paymentStatus = ""
        staffId = ""
        sellerId = ""
        sellerName = ""
        loadTransactions(isRefresh: true)
    }

    /// The Settlements sheet's filters, all at once, one fetch. A preset other than custom
    /// recomputes its range here so "This Week" etc. are always current.
    func applySettlementFilters(_ filters: PaymentSettlementFilters) {
        var filters = filters
        if filters.datePreset != .custom, let range = OrderInsightsDatePreset.dateRange(for: filters.datePreset) {
            filters.startDate = range.start
            filters.endDate = range.end
        }
        if filters.sellerId.isEmptyString { filters.sellerName = "" }
        settlementFilters = filters
        loadSettlements(isRefresh: true)
    }

    /// Settlements back to today, every mode and seller.
    func resetSettlementFilters() {
        applySettlementFilters(.today)
    }

    func currentAppliedFilters() -> PaymentInsightsAppliedFilters {
        PaymentInsightsAppliedFilters(
            startDate: startDate,
            endDate: endDate,
            datePreset: selectedDatePreset,
            paymentMode: paymentMode,
            paymentStatus: paymentStatus,
            staffId: staffId,
            sellerId: sellerId,
            sellerName: sellerName
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

        // Search fires per keystroke; only the latest query's results may land.
        sellerCancellable = service.getSellerList(
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
            self.sellerTotal = response.data.total
        }
    }
}
