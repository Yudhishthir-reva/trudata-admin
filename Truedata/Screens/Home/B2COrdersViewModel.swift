//
//  B2COrdersViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

class B2COrdersViewModel: ObservableObject {

    @Published var orders: [B2CCustomerOrderItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    // Multi-dimensional filters
    @Published var selectedDateRange: B2CDateRangeFilter = .thisMonth
    @Published var selectedStatus: B2COrderStatusFilter = .all
    @Published var selectedPaymentMode: B2CPaymentModeFilter = .all

    // Last used filter metadata (persisted)
    @Published var lastUsedDateRange: B2CDateRangeFilter = .thisMonth
    @Published var lastUsedStatus: B2COrderStatusFilter = .all
    @Published var lastUsedPaymentMode: B2CPaymentModeFilter = .all

    @Published var pagination: B2CPagination?

    private var cancellables = Set<AnyCancellable>()
    private let service: B2COrdersServiceManager
    private var currentPage = 1
    private var hasMorePages = true

    init(service: B2COrdersServiceManager = B2COrdersServiceManager()) {
        self.service = service
        loadSavedFilters()
    }

    var hasActiveFilters: Bool {
        selectedStatus != .all || selectedDateRange != .thisMonth || selectedPaymentMode != .all
    }

    var lastUsedFilterSubtitle: String {
        "\(lastUsedStatus.rawValue) · \(lastUsedDateRange.rawValue)"
    }

    var filteredOrders: [B2CCustomerOrderItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return orders.filter { order in
            let matchesQuery = query.isEmpty ||
                order.orderNo.lowercased().contains(query) ||
                order.customerName.lowercased().contains(query) ||
                order.customerMobile.contains(query) ||
                order.customerAddress.lowercased().contains(query) ||
                order.resolvedStatusLabel.lowercased().contains(query)

            let matchesDate = order.matches(dateRange: selectedDateRange)
            let matchesStatus = order.matches(statusFilter: selectedStatus)
            let matchesPayment = order.matches(paymentMode: selectedPaymentMode)

            return matchesQuery && matchesDate && matchesStatus && matchesPayment
        }
    }

    var totalOrderCount: Int {
        filteredOrders.count
    }

    var totalAmountSum: Double {
        filteredOrders.reduce(0.0) { $0 + $1.totalAmount }
    }

    var pendingOrdersCount: Int {
        orders.filter { $0.status?.code == 0 || $0.resolvedStatusLabel.lowercased() == "pending" }.count
    }

    func loadOrders(isRefresh: Bool = false) {
        if isRefresh {
            isRefreshing = true
            currentPage = 1
            hasMorePages = true
        } else {
            isLoading = true
            currentPage = 1
            hasMorePages = true
        }
        errorMessage = nil

        service.getB2COrders(status: selectedStatus.statusCode, page: 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                if response.status {
                    self.orders = response.data
                    self.pagination = response.pagination
                    self.currentPage = response.pagination?.currentPage ?? 1
                    self.hasMorePages = response.pagination?.hasMore ?? (response.data.count >= 10)
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Failed to load B2C orders" : response.message
                }
            }
            .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentOrder: B2CCustomerOrderItem) {
        guard let lastOrder = orders.last, lastOrder.id == currentOrder.id else { return }
        guard !isLoadingMore, !isLoading, hasMorePages else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        service.getB2COrders(status: selectedStatus.statusCode, page: nextPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingMore = false
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingMore = false
                if response.status {
                    self.orders.append(contentsOf: response.data)
                    self.pagination = response.pagination
                    self.currentPage = response.pagination?.currentPage ?? nextPage
                    self.hasMorePages = response.pagination?.hasMore ?? (response.data.count >= 10)
                }
            }
            .store(in: &cancellables)
    }

    func applyFilters(
        dateRange: B2CDateRangeFilter,
        status: B2COrderStatusFilter,
        paymentMode: B2CPaymentModeFilter
    ) {
        let statusChanged = selectedStatus != status
        selectedDateRange = dateRange
        selectedStatus = status
        selectedPaymentMode = paymentMode

        // Save as last used filter
        lastUsedDateRange = dateRange
        lastUsedStatus = status
        lastUsedPaymentMode = paymentMode
        saveFilters()

        if statusChanged || orders.isEmpty {
            loadOrders()
        }
    }

    func applyLastUsedFilter() {
        applyFilters(
            dateRange: lastUsedDateRange,
            status: lastUsedStatus,
            paymentMode: lastUsedPaymentMode
        )
    }

    func resetToDefaultFilters() {
        applyFilters(
            dateRange: .thisMonth,
            status: .all,
            paymentMode: .all
        )
    }

    private func saveFilters() {
        UserDefaults.standard.set(lastUsedDateRange.rawValue, forKey: "b2c_filter_date_range")
        UserDefaults.standard.set(lastUsedStatus.rawValue, forKey: "b2c_filter_status")
        UserDefaults.standard.set(lastUsedPaymentMode.rawValue, forKey: "b2c_filter_payment")
    }

    private func loadSavedFilters() {
        if let d = UserDefaults.standard.string(forKey: "b2c_filter_date_range"),
           let dr = B2CDateRangeFilter(rawValue: d) {
            lastUsedDateRange = dr
        }
        if let s = UserDefaults.standard.string(forKey: "b2c_filter_status"),
           let st = B2COrderStatusFilter(rawValue: s) {
            lastUsedStatus = st
        }
        if let p = UserDefaults.standard.string(forKey: "b2c_filter_payment"),
           let pm = B2CPaymentModeFilter(rawValue: p) {
            lastUsedPaymentMode = pm
        }
    }
}
