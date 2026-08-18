//
//  SellerProfileViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class SellerProfileViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profile: SellerProfileInfo?
    @Published var financialStats: SellerProfileFinancialStats?
    @Published var orderDistribution: SellerProfileOrderDistribution?
    @Published var paymentMode: SellerProfilePaymentModeCounts?
    @Published var paymentModeAmount: SellerProfilePaymentModeAmounts?
    @Published var topProducts: [SellerProfileTopProduct] = []
    @Published var topCategories: [SellerProfileTopCategory] = []
    @Published var canCreateOrder = false
    @Published var colorList: [SellerProfileColorItem] = []
    @Published var isUpdatingColor = false
    @Published var colorUpdateMessage: String?
    @Published var showColorUpdateAlert = false

    @Published var ordersLoading = false
    @Published var ordersLoadingMore = false
    @Published var ordersError: String?
    @Published var orders: [SellerProfileOrderItem] = []
    @Published var orderStatusMap: [SellerProfileOrderStatusOption] = []
    @Published var orderIdSearch = ""
    @Published var selectedOrderStatus = ""
    @Published var ordersDatePreset: SellerProfileDatePreset = .thisMonth
    @Published var ordersStartDate: String
    @Published var ordersEndDate: String
    @Published var ordersShowCustomDates = false

    @Published var paymentsLoading = false
    @Published var paymentsLoadingMore = false
    @Published var paymentsError: String?
    @Published var transactions: [SellerProfileTransactionItem] = []
    @Published var transactionIdSearch = ""
    @Published var selectedTransactionStatus = ""
    @Published var paymentsDatePreset: SellerProfileDatePreset = .lastMonth
    @Published var paymentsStartDate: String
    @Published var paymentsEndDate: String
    @Published var paymentsShowCustomDates = false

    @Published var selectedTab: SellerProfileTab = .stats
    @Published var scrollToTabBarToken = UUID()
    @Published var selectedDatePreset: SellerProfileDatePreset = .thisMonth
    @Published var startDate: String
    @Published var endDate: String
    @Published var showCustomDatePickers = false

    private let sellerId: String
    private let sellerIdInt: Int
    private let service = SellerProfileServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var ordersPage = 1
    private var ordersCanLoadMore = false
    private var paymentsPage = 1
    private var paymentsCanLoadMore = false
    private var ordersLoadedOnce = false
    private var paymentsLoadedOnce = false

    init(sellerId: Int) {
        self.sellerIdInt = sellerId
        self.sellerId = String(sellerId)
        let monthRange = SellerProfileDatePreset.thisMonth.dateRange()
        self.startDate = monthRange.start
        self.endDate = monthRange.end
        self.selectedDatePreset = .thisMonth

        let ordersRange = SellerProfileDatePreset.thisMonth.dateRange()
        self.ordersStartDate = ordersRange.start
        self.ordersEndDate = ordersRange.end

        let paymentsRange = SellerProfileDatePreset.lastMonth.dateRange()
        self.paymentsStartDate = paymentsRange.start
        self.paymentsEndDate = paymentsRange.end

        bindSearchDebounces()
    }

    var profileSellerId: Int { sellerIdInt }

    var screenTitle: String {
        profile?.name.isEmptyString == false ? profile!.name : "Seller Profile"
    }

    var summaryTitle: String {
        "\(profile?.displayOwnerName ?? "Seller")'s Summary"
    }

    var orderChartTotal: Int {
        orderDistribution?.pending ?? 0
    }

    var totalValidOrders: Int {
        let pending = orderDistribution?.pending ?? 0
        let cancelled = orderDistribution?.cancel ?? 0
        return max(pending - cancelled, 0)
    }

    var totalOrderAmount: Double {
        financialStats?.totalAmount.parsedAmount ?? 0
    }

    var settledAmount: Double {
        financialStats?.paidAmount.parsedAmount ?? 0
    }

    var pendingAmount: Double {
        financialStats?.pendingAmount.parsedAmount ?? 0
    }

    var paymentModeTotalCount: Int {
        (paymentMode?.cash ?? 0) + (paymentMode?.upi ?? 0) + (paymentMode?.cheque ?? 0)
    }

    var orderLegendItems: [SellerProfileLegendItem] {
        guard let distribution = orderDistribution else { return SellerProfileLegendItem.emptyList }
        return [
            .init(title: "Delivered", count: distribution.delivered, color: DashboardTheme.successGreen),
            .init(title: "Pending", count: distribution.pending, color: DashboardTheme.warningYellow),
            .init(title: "To Deliver", count: distribution.toDeliver, color: DashboardTheme.infoBlue),
            .init(title: "Assigned", count: distribution.assign, color: DashboardTheme.primaryBlue),
            .init(title: "Pickup", count: distribution.pickup, color: DashboardTheme.pickupOrange),
            .init(title: "Cancelled", count: distribution.cancel, color: DashboardTheme.dangerRed),
            .init(title: "Returned", count: distribution.returnCount, color: DashboardTheme.neutralMedium)
        ]
    }

    var orderChartSegments: [DashboardChartSegment] {
        guard let distribution = orderDistribution else { return [] }
        return [
            DashboardChartSegment(value: Double(distribution.delivered), color: DashboardTheme.successGreen),
            DashboardChartSegment(value: Double(distribution.pending), color: DashboardTheme.warningYellow),
            DashboardChartSegment(value: Double(distribution.toDeliver), color: DashboardTheme.infoBlue),
            DashboardChartSegment(value: Double(distribution.assign), color: DashboardTheme.primaryBlue),
            DashboardChartSegment(value: Double(distribution.pickup), color: DashboardTheme.pickupOrange),
            DashboardChartSegment(value: Double(distribution.cancel), color: DashboardTheme.dangerRed),
            DashboardChartSegment(value: Double(distribution.returnCount), color: DashboardTheme.neutralMedium)
        ].filter { $0.value > 0 }
    }

    var amountChartSegments: [DashboardChartSegment] {
        [
            DashboardChartSegment(value: settledAmount, color: DashboardTheme.successGreen),
            DashboardChartSegment(value: pendingAmount, color: DashboardTheme.warningYellow)
        ].filter { $0.value > 0 }
    }

    var paymentModeTotalAmount: Double {
        (paymentModeAmount?.cash.parsedAmount ?? 0)
            + (paymentModeAmount?.upi.parsedAmount ?? 0)
            + (paymentModeAmount?.cheque.parsedAmount ?? 0)
    }

    func paymentChartSegments(mode: SellerProfilePaymentChartMode) -> [DashboardChartSegment] {
        switch mode {
        case .count:
            return [
                DashboardChartSegment(value: Double(paymentMode?.cash ?? 0), color: DashboardTheme.successGreen),
                DashboardChartSegment(value: Double(paymentMode?.upi ?? 0), color: DashboardTheme.infoBlue),
                DashboardChartSegment(value: Double(paymentMode?.cheque ?? 0), color: DashboardTheme.warningYellow)
            ].filter { $0.value > 0 }
        case .amount:
            return [
                DashboardChartSegment(value: paymentModeAmount?.cash.parsedAmount ?? 0, color: DashboardTheme.successGreen),
                DashboardChartSegment(value: paymentModeAmount?.upi.parsedAmount ?? 0, color: DashboardTheme.infoBlue),
                DashboardChartSegment(value: paymentModeAmount?.cheque.parsedAmount ?? 0, color: DashboardTheme.warningYellow)
            ].filter { $0.value > 0 }
        }
    }

    func paymentLegendRows(mode: SellerProfilePaymentChartMode) -> [SellerProfilePaymentLegendRow] {
        switch mode {
        case .count:
            let total = Double(max(paymentModeTotalCount, 1))
            return [
                .init(
                    title: "Cash",
                    primaryValue: "\(paymentMode?.cash ?? 0)",
                    percentage: paymentPercentage(Double(paymentMode?.cash ?? 0), total: total),
                    color: DashboardTheme.successGreen
                ),
                .init(
                    title: "UPI",
                    primaryValue: "\(paymentMode?.upi ?? 0)",
                    percentage: paymentPercentage(Double(paymentMode?.upi ?? 0), total: total),
                    color: DashboardTheme.infoBlue
                ),
                .init(
                    title: "Cheque",
                    primaryValue: "\(paymentMode?.cheque ?? 0)",
                    percentage: paymentPercentage(Double(paymentMode?.cheque ?? 0), total: total),
                    color: DashboardTheme.warningYellow
                )
            ]
        case .amount:
            let total = max(paymentModeTotalAmount, 1)
            return [
                .init(
                    title: "Cash",
                    primaryValue: (paymentModeAmount?.cash.parsedAmount ?? 0).currencyLabel,
                    percentage: paymentPercentage(paymentModeAmount?.cash.parsedAmount ?? 0, total: total),
                    color: DashboardTheme.successGreen
                ),
                .init(
                    title: "UPI",
                    primaryValue: (paymentModeAmount?.upi.parsedAmount ?? 0).currencyLabel,
                    percentage: paymentPercentage(paymentModeAmount?.upi.parsedAmount ?? 0, total: total),
                    color: DashboardTheme.infoBlue
                ),
                .init(
                    title: "Cheque",
                    primaryValue: (paymentModeAmount?.cheque.parsedAmount ?? 0).currencyLabel,
                    percentage: paymentPercentage(paymentModeAmount?.cheque.parsedAmount ?? 0, total: total),
                    color: DashboardTheme.warningYellow
                )
            ]
        }
    }

    func paymentChartTotalLabel(mode: SellerProfilePaymentChartMode) -> String {
        switch mode {
        case .count:
            return "\(paymentModeTotalCount)"
        case .amount:
            return paymentModeTotalAmount.compactCurrencyLabel
        }
    }

    private func paymentPercentage(_ value: Double, total: Double) -> String {
        guard total > 0 else { return "0.0%" }
        return String(format: "%.1f%%", (value / total) * 100)
    }

    var availablePaymentFlags: [SellerProfileColorItem] {
        colorList.isEmpty ? SellerProfileColorItem.fallbackItems : colorList
    }

    var canUpdatePaymentFlag: Bool {
        profile?.canUpdateColor == true && !availablePaymentFlags.isEmpty
    }

    func loadProfile(isRefresh: Bool = false) {
        if !isRefresh {
            isLoading = profile == nil
        }
        errorMessage = nil

        service.getSellerProfile(
            sellerId: sellerId,
            startDate: startDate,
            endDate: endDate
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            if response.status, let data = response.data {
                self.profile = data.profile
                self.financialStats = data.financialStats
                self.orderDistribution = data.orderDistribution
                self.paymentMode = data.paymentMode
                self.paymentModeAmount = data.paymentModeAmount
                self.topProducts = data.topProducts
                self.topCategories = data.topCategories
                self.canCreateOrder = response.canCreateOrder
                if self.profile?.canUpdateColor == true {
                    self.loadColorList()
                }
                if !self.ordersLoadedOnce {
                    self.loadOrders(isInitial: true)
                }
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load seller profile"
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadColorList() {
        service.getColorList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.colorList = response.colors
                }
            }
            .store(in: &cancellables)
    }

    func updatePaymentFlag(colorId: Int) {
        guard canUpdatePaymentFlag else { return }
        guard profile?.colorId != colorId else { return }

        isUpdatingColor = true
        colorUpdateMessage = nil

        service.updateSellerColor(sellerId: sellerIdInt, colorId: colorId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isUpdatingColor = false
                if case .failure(let error) = completion {
                    self?.colorUpdateMessage = error.localizedDescription
                    self?.showColorUpdateAlert = true
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingColor = false
                if response.status {
                    self.colorUpdateMessage = response.message.isEmptyString
                        ? "Payment flag updated successfully"
                        : response.message
                    self.loadProfile(isRefresh: true)
                } else {
                    self.colorUpdateMessage = response.message.isEmptyString
                        ? "Failed to update payment flag"
                        : response.message
                }
                self.showColorUpdateAlert = true
            }
            .store(in: &cancellables)
    }

    func selectDatePreset(_ preset: SellerProfileDatePreset) {
        selectedDatePreset = preset
        if preset == .custom {
            showCustomDatePickers = true
            return
        }
        showCustomDatePickers = false
        let range = preset.dateRange()
        startDate = range.start
        endDate = range.end
        loadProfile(isRefresh: true)
    }

    func updateStartDate(_ value: String) {
        startDate = value
        selectedDatePreset = .custom
        showCustomDatePickers = true
        loadProfile(isRefresh: true)
    }

    func updateEndDate(_ value: String) {
        endDate = value
        selectedDatePreset = .custom
        showCustomDatePickers = true
        loadProfile(isRefresh: true)
    }

    func onTabSelected(_ tab: SellerProfileTab) {
        switch tab {
        case .orders where !ordersLoadedOnce:
            loadOrders(isInitial: true)
        case .payments where !paymentsLoadedOnce:
            loadPayments(isInitial: true)
        default:
            break
        }
    }

    func openOrdersTab() {
        selectedTab = .orders
        onTabSelected(.orders)
        scrollToTabBarToken = UUID()
    }

    private func bindSearchDebounces() {
        $orderIdSearch
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resetAndFetchOrders()
            }
            .store(in: &cancellables)

        $transactionIdSearch
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resetAndFetchPayments()
            }
            .store(in: &cancellables)
    }

    // MARK: - Orders Tab

    func loadOrders(isInitial: Bool = false) {
        if isInitial {
            ordersPage = 1
            ordersCanLoadMore = false
            if orders.isEmpty { ordersLoading = true }
        } else {
            guard ordersCanLoadMore, !ordersLoadingMore, !ordersLoading else { return }
            ordersLoadingMore = true
        }
        ordersError = nil

        service.getSellerOrders(
            sellerId: sellerId,
            page: ordersPage,
            startDate: ordersStartDate,
            endDate: ordersEndDate,
            orderStatus: selectedOrderStatus,
            orderId: orderIdSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.ordersLoading = false
            self.ordersLoadingMore = false
            if case .failure(let error) = completion {
                self.ordersError = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.ordersLoading = false
            self.ordersLoadingMore = false
            self.ordersLoadedOnce = true
            if response.status {
                if isInitial || self.ordersPage == 1 {
                    self.orders = response.orders
                } else {
                    self.orders.append(contentsOf: response.orders)
                }
                if self.orderStatusMap.isEmpty {
                    self.orderStatusMap = response.statusMap
                }
                self.ordersCanLoadMore = response.canLoadMore
            } else {
                self.ordersError = response.message.isEmptyString ? "Failed to load orders" : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadMoreOrdersIfNeeded(currentOrder: SellerProfileOrderItem) {
        guard let last = orders.last, last.id == currentOrder.id else { return }
        guard ordersCanLoadMore, !ordersLoadingMore else { return }
        ordersPage += 1
        loadOrders(isInitial: false)
    }

    func resetAndFetchOrders() {
        ordersPage = 1
        ordersCanLoadMore = false
        orders = []
        loadOrders(isInitial: true)
    }

    func selectOrdersDatePreset(_ preset: SellerProfileDatePreset) {
        ordersDatePreset = preset
        if preset == .custom {
            ordersShowCustomDates = true
            return
        }
        ordersShowCustomDates = false
        let range = preset.dateRange()
        ordersStartDate = range.start
        ordersEndDate = range.end
        resetAndFetchOrders()
    }

    func updateOrdersStartDate(_ value: String) {
        ordersStartDate = value
        ordersDatePreset = .custom
        ordersShowCustomDates = true
        resetAndFetchOrders()
    }

    func updateOrdersEndDate(_ value: String) {
        ordersEndDate = value
        ordersDatePreset = .custom
        ordersShowCustomDates = true
        resetAndFetchOrders()
    }

    func selectOrderStatus(_ statusKey: String) {
        selectedOrderStatus = selectedOrderStatus == statusKey ? "" : statusKey
        resetAndFetchOrders()
    }

    // MARK: - Payments Tab

    func loadPayments(isInitial: Bool = false) {
        if isInitial {
            paymentsPage = 1
            paymentsCanLoadMore = false
            if transactions.isEmpty { paymentsLoading = true }
        } else {
            guard paymentsCanLoadMore, !paymentsLoadingMore, !paymentsLoading else { return }
            paymentsLoadingMore = true
        }
        paymentsError = nil

        service.getSellerTransactions(
            sellerId: sellerId,
            page: paymentsPage,
            startDate: paymentsStartDate,
            endDate: paymentsEndDate,
            transactionStatus: selectedTransactionStatus,
            transactionId: transactionIdSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.paymentsLoading = false
            self.paymentsLoadingMore = false
            if case .failure(let error) = completion {
                self.paymentsError = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.paymentsLoading = false
            self.paymentsLoadingMore = false
            self.paymentsLoadedOnce = true
            if response.status {
                if isInitial || self.paymentsPage == 1 {
                    self.transactions = response.transactions
                } else {
                    self.transactions.append(contentsOf: response.transactions)
                }
                self.paymentsCanLoadMore = response.canLoadMore
            } else {
                self.paymentsError = response.message.isEmptyString ? "Failed to load payments" : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadMorePaymentsIfNeeded(currentTransaction: SellerProfileTransactionItem) {
        guard let last = transactions.last, last.id == currentTransaction.id else { return }
        guard paymentsCanLoadMore, !paymentsLoadingMore else { return }
        paymentsPage += 1
        loadPayments(isInitial: false)
    }

    func resetAndFetchPayments() {
        paymentsPage = 1
        paymentsCanLoadMore = false
        transactions = []
        loadPayments(isInitial: true)
    }

    func selectPaymentsDatePreset(_ preset: SellerProfileDatePreset) {
        paymentsDatePreset = preset
        if preset == .custom {
            paymentsShowCustomDates = true
            return
        }
        paymentsShowCustomDates = false
        let range = preset.dateRange()
        paymentsStartDate = range.start
        paymentsEndDate = range.end
        resetAndFetchPayments()
    }

    func updatePaymentsStartDate(_ value: String) {
        paymentsStartDate = value
        paymentsDatePreset = .custom
        paymentsShowCustomDates = true
        resetAndFetchPayments()
    }

    func updatePaymentsEndDate(_ value: String) {
        paymentsEndDate = value
        paymentsDatePreset = .custom
        paymentsShowCustomDates = true
        resetAndFetchPayments()
    }

    func selectTransactionStatus(_ filter: SellerProfileTransactionStatusFilter) {
        let apiKey = filter.apiKey
        selectedTransactionStatus = selectedTransactionStatus == apiKey ? "" : apiKey
        resetAndFetchPayments()
    }

    func isTransactionStatusSelected(_ filter: SellerProfileTransactionStatusFilter) -> Bool {
        selectedTransactionStatus == filter.apiKey
    }
}
