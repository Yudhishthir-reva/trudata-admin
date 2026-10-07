//
//  AllSourceOrdersViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class AllSourceOrdersViewModel: ObservableObject {

    /// Flip when `V2/all-order-list` starts filtering by `search` server-side.
    static let serverSearchReady = false

    @Published var filter: AllSourceOrdersFilter
    @Published var orders: [AllSourceOrderItem] = []
    @Published var summary: [AllSourceOrderStatusSummary] = []
    @Published var totalRecords = 0
    @Published var searchQuery = ""
    @Published var isLoading = true
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false
    @Published var errorMessage: String?
    @Published var showFilterSheet = false
    @Published var showSummaryBreakdown = false

    private let service: AllSourceOrdersServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var loadCancellable: AnyCancellable?
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var hasLoadedOnce = false
    private var appliedSearch = ""

    var visibleOrders: [AllSourceOrderItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty || Self.serverSearchReady { return orders }
        return orders.filter {
            $0.orderNo.lowercased().contains(query)
                || $0.sellerName.lowercased().contains(query)
                || $0.staffName.lowercased().contains(query)
                || $0.sellerMobile.contains(query)
        }
    }

    var summaryMetrics: AllSourceOrdersSummaryMetrics {
        AllSourceOrdersSummaryMetrics(summary: summary)
    }

    init(
        initialSource: AllSourceOrderSource = .all,
        service: AllSourceOrdersServiceManager = AllSourceOrdersServiceManager()
    ) {
        self.filter = AllSourceOrdersFilter(source: initialSource)
        self.service = service
    }

    func ensureLoaded() {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        load(reset: true)
    }

    func refresh() {
        load(reset: true, isRefresh: true)
    }

    func selectSource(_ source: AllSourceOrderSource) {
        applyFilter(AllSourceOrdersFilter(
            source: source,
            preset: filter.preset,
            startDate: filter.startDate,
            endDate: filter.endDate
        ))
    }

    func applyFilter(_ newFilter: AllSourceOrdersFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        load(reset: true)
    }

    func resetFilters() {
        applyFilter(AllSourceOrdersFilter())
    }

    func onSearchQueryChange(_ query: String) {
        searchQuery = query
        searchCancellable?.cancel()
        searchCancellable = Just(query)
            .delay(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed != self.appliedSearch {
                    self.load(reset: true, isRefresh: true)
                }
            }
    }

    func loadMoreIfNeeded(currentItem: AllSourceOrderItem) {
        guard let index = visibleOrders.firstIndex(where: { $0.id == currentItem.id }) else { return }
        let threshold = max(visibleOrders.count - 4, 0)
        guard index >= threshold else { return }
        loadMore()
    }

    func loadMore() {
        guard canLoadMore, !isLoadingMore, !isLoading, loadCancellable == nil else { return }
        load(reset: false)
    }

    private func load(reset: Bool, isRefresh: Bool = false) {
        loadCancellable?.cancel()
        if reset { currentPage = 1 }

        let search = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if reset { appliedSearch = search }
        let page = reset ? 1 : currentPage + 1

        if isRefresh && !orders.isEmpty {
            isRefreshing = true
            errorMessage = nil
        } else if reset {
            isLoading = true
            orders = []
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        loadCancellable = service.fetchOrders(
            orderSource: filter.source.rawValue,
            startDate: filter.startDate,
            endDate: filter.endDate,
            page: page,
            search: appliedSearch
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.loadCancellable = nil
            self.isLoading = false
            self.isRefreshing = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, reset {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status {
                let pageData = response.data
                self.currentPage = pageData.currentPage
                self.orders = reset ? pageData.orders : self.orders + pageData.orders
                if !pageData.summary.isEmpty {
                    self.summary = pageData.summary
                }
                self.totalRecords = pageData.total
                self.canLoadMore = pageData.currentPage < pageData.lastPage
                self.errorMessage = nil
            } else {
                let message = response.message.isEmptyString ? "Couldn't load orders" : response.message
                if reset {
                    self.errorMessage = message
                }
            }
        }
    }
}
