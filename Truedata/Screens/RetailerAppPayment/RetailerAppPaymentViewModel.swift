//
//  RetailerAppPaymentViewModel.swift
//  Truedata
//

import Foundation
import Combine

class RetailerAppPaymentViewModel: ObservableObject {

    @Published var selectedTab: RetailerPaymentStatus = .pending {
        didSet {
            if oldValue != selectedTab {
                loadRequests(isRefresh: true)
            }
        }
    }

    @Published var items: [RetailerPaymentItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var canLoadMore: Bool = false
    @Published var currentPage: Int = 1

    @Published var pendingCount: Int = 0
    @Published var approvedCount: Int = 0
    @Published var rejectedCount: Int = 0

    @Published var searchText: String = ""
    @Published var filters: RetailerPaymentFilters = RetailerPaymentFilters()
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var isLoadingSellers: Bool = false

    @Published var isActioning: Bool = false
    @Published var toastMessage: String?
    @Published var errorMessage: String?

    private let service: RetailerAppPaymentServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var toastTimer: AnyCancellable?

    init(service: RetailerAppPaymentServiceManager = RetailerAppPaymentServiceManager()) {
        self.service = service
        setupDefaultDates()
    }

    private func setupDefaultDates() {
        let range = filters.datePreset.dateRange()
        filters.startDate = range.start
        filters.endDate = range.end
    }

    var bannerTitle: String {
        switch filters.datePreset {
        case .today:
            return "Showing today"
        case .yesterday:
            return "Showing yesterday"
        case .last7Days:
            return "Showing last 7 days"
        case .thisMonth:
            return "Showing this month"
        case .allTime:
            return "Showing all time"
        case .custom:
            if !filters.startDate.isEmpty && !filters.endDate.isEmpty {
                return "Showing \(filters.startDate) to \(filters.endDate)"
            }
            return "Showing custom range"
        }
    }

    var countForCurrentTab: Int {
        switch selectedTab {
        case .pending:
            return pendingCount > 0 ? pendingCount : items.count
        case .approved:
            return approvedCount > 0 ? approvedCount : items.count
        case .rejected:
            return rejectedCount > 0 ? rejectedCount : items.count
        }
    }

    func countForTab(_ tab: RetailerPaymentStatus) -> Int {
        switch tab {
        case .pending: return pendingCount
        case .approved: return approvedCount
        case .rejected: return rejectedCount
        }
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(text.isEmpty ? 0 : 400), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadRequests(isRefresh: true)
            }
    }

    func loadRequests(isRefresh: Bool = true) {
        if isRefresh {
            currentPage = 1
            canLoadMore = false
        }

        if isRefresh {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        errorMessage = nil

        let statusQuery = selectedTab.rawValue
        let (startDate, endDate) = resolveDateQuery()

        service.fetchPaymentRequests(
            status: statusQuery,
            sellerId: filters.sellerId,
            startDate: startDate,
            endDate: endDate,
            search: searchText,
            perPage: 15,
            page: currentPage
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion {
                if self.items.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false

            let newItems = response.data.payments
            if isRefresh {
                self.items = newItems
            } else {
                self.items.append(contentsOf: newItems)
            }

            self.currentPage = response.data.currentPage
            self.canLoadMore = response.data.currentPage < response.data.lastPage

            if response.data.pendingCount > 0 || response.data.approvedCount > 0 || response.data.rejectedCount > 0 {
                self.pendingCount = response.data.pendingCount
                self.approvedCount = response.data.approvedCount
                self.rejectedCount = response.data.rejectedCount
            } else {
                self.updateCountForCurrentTab(count: response.data.total > 0 ? response.data.total : self.items.count)
            }
        }
        .store(in: &cancellables)
    }

    private func updateCountForCurrentTab(count: Int) {
        switch selectedTab {
        case .pending:
            pendingCount = count
        case .approved:
            approvedCount = count
        case .rejected:
            rejectedCount = count
        }
    }

    private func resolveDateQuery() -> (start: String, end: String) {
        switch filters.datePreset {
        case .allTime:
            return ("", "")
        case .custom:
            return (filters.startDate, filters.endDate)
        default:
            let range = filters.datePreset.dateRange()
            return (range.start, range.end)
        }
    }

    func loadMoreIfNeeded(currentItem: RetailerPaymentItem) {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = items.firstIndex(of: currentItem) else { return }
        if index >= items.count - 3 {
            currentPage += 1
            loadRequests(isRefresh: false)
        }
    }

    func applyFilters(_ newFilters: RetailerPaymentFilters) {
        filters = newFilters
        loadRequests(isRefresh: true)
    }

    func switchToAllTime() {
        filters.datePreset = .allTime
        filters.startDate = ""
        filters.endDate = ""
        loadRequests(isRefresh: true)
    }

    func resetFiltersToDefault() {
        filters = RetailerPaymentFilters()
        setupDefaultDates()
        loadRequests(isRefresh: true)
    }

    func approvePayment(item: RetailerPaymentItem, remark: String = "") {
        isActioning = true
        errorMessage = nil

        service.updatePaymentStatus(id: item.id, status: "1", remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isActioning = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isActioning = false
                self.items.removeAll(where: { $0.id == item.id })
                self.pendingCount = max(0, self.pendingCount - 1)
                self.approvedCount += 1
                self.showToast("Status updated successfully")
            }
            .store(in: &cancellables)
    }

    func rejectPayment(item: RetailerPaymentItem, remark: String) {
        isActioning = true
        errorMessage = nil

        service.updatePaymentStatus(id: item.id, status: "2", remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isActioning = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isActioning = false
                self.items.removeAll(where: { $0.id == item.id })
                self.pendingCount = max(0, self.pendingCount - 1)
                self.rejectedCount += 1
                self.showToast("Status updated successfully")
            }
            .store(in: &cancellables)
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTimer?.cancel()
        toastTimer = Just(())
            .delay(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.toastMessage = nil
            }
    }

    func loadSellersIfNeeded() {
        guard sellerList.isEmpty, !isLoadingSellers else { return }
        isLoadingSellers = true
        service.fetchSellerList(page: 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLoadingSellers = false
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingSellers = false
                if response.status {
                    self.sellerList = response.data.sellers
                }
            }
            .store(in: &cancellables)
    }
}
