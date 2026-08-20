//
//  QuickShareViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class QuickShareViewModel: ObservableObject {

    @Published var selectedDate = OrderInsightsDateFormat.todayString
    @Published var viewMode: QuickShareViewMode = .exportAll
    @Published var selectedStaffId = ""
    @Published var selectedStaffName = "All Staff"
    @Published var selectedSellerId = ""
    @Published var selectedSellerName = "All Sellers"
    @Published var selectedOrderStatus = ""
    @Published var selectedOrderStatusLabel = "All Orders"

    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var orders: [OrderInsightsOrder] = []
    @Published var selectedOrderNos: Set<String> = []

    @Published var isLoadingFilters = false
    @Published var isLoadingOrders = false
    @Published var isLoadingMoreOrders = false
    @Published var isExporting = false
    @Published var errorMessage: String?
    @Published var exportShareURL: URL?
    @Published var exportAlertMessage: String?

    private let service: QuickShareServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var currentOrderPage = 1
    private var lastOrderPage = 1

    var hasActiveFilters: Bool {
        !selectedStaffId.isEmptyString
            || !selectedSellerId.isEmptyString
            || !selectedOrderStatus.isEmptyString
    }

    var canLoadMoreOrders: Bool {
        currentOrderPage < lastOrderPage
    }

    init(service: QuickShareServiceManager = QuickShareServiceManager()) {
        self.service = service
    }

    func loadInitial() {
        loadFilterData()
        if viewMode == .selectOrders {
            loadOrders(reset: true)
        }
    }

    func refresh() {
        loadFilterData()
        if viewMode == .selectOrders {
            loadOrders(reset: true)
        }
    }

    func onViewModeChanged(_ mode: QuickShareViewMode) {
        viewMode = mode
        selectedOrderNos.removeAll()
        if mode == .selectOrders {
            loadOrders(reset: true)
        }
    }

    func onDateChanged(_ date: String) {
        selectedDate = OrderInsightsDateFormat.normalizedAPIString(from: date)
        selectedOrderNos.removeAll()
        if viewMode == .selectOrders {
            loadOrders(reset: true)
        }
    }

    func applyFilters(
        staffId: String,
        staffName: String,
        sellerId: String,
        sellerName: String,
        orderStatus: String,
        orderStatusLabel: String
    ) {
        selectedStaffId = staffId
        selectedStaffName = staffName.isEmptyString ? "All Staff" : staffName
        selectedSellerId = sellerId
        selectedSellerName = sellerName.isEmptyString ? "All Sellers" : sellerName
        selectedOrderStatus = orderStatus
        selectedOrderStatusLabel = orderStatusLabel.isEmptyString ? "All Orders" : orderStatusLabel
        selectedOrderNos.removeAll()
        if viewMode == .selectOrders {
            loadOrders(reset: true)
        }
    }

    func resetFilters() {
        applyFilters(
            staffId: "",
            staffName: "All Staff",
            sellerId: "",
            sellerName: "All Sellers",
            orderStatus: "",
            orderStatusLabel: "All Orders"
        )
    }

    func toggleOrderSelection(_ orderNo: String) {
        if selectedOrderNos.contains(orderNo) {
            selectedOrderNos.remove(orderNo)
        } else {
            selectedOrderNos.insert(orderNo)
        }
    }

    func loadMoreOrdersIfNeeded(currentOrder: OrderInsightsOrder) {
        guard viewMode == .selectOrders,
              !isLoadingOrders,
              !isLoadingMoreOrders,
              canLoadMoreOrders,
              let last = orders.last,
              last.id == currentOrder.id else { return }
        loadOrders(reset: false)
    }

    func exportInvoicePDF() {
        guard !selectedDate.isEmptyString else {
            exportAlertMessage = "Please select a date."
            return
        }

        if viewMode == .selectOrders {
            guard !selectedOrderNos.isEmpty else {
                exportAlertMessage = "Please select at least one order."
                return
            }
            exportBulkInvoice()
            return
        }

        isExporting = true
        exportAlertMessage = nil

        service.downloadQuickSharePDF(
            orderDate: selectedDate,
            staffId: selectedStaffId.nilIfEmpty,
            sellerId: selectedSellerId.nilIfEmpty,
            orderStatus: selectedOrderStatus.nilIfEmpty
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isExporting = false
            if case .failure(let error) = completion {
                self.exportAlertMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] data in
            self?.sharePDF(data: data, prefix: "QuickShare_\(self?.selectedDate ?? "")")
        }
        .store(in: &cancellables)
    }

    private func exportBulkInvoice() {
        isExporting = true
        exportAlertMessage = nil

        service.downloadBulkInvoicePDF(selectedOrderNos: Array(selectedOrderNos).sorted())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isExporting = false
                if case .failure(let error) = completion {
                    self.exportAlertMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] data in
                self?.sharePDF(data: data, prefix: "Bulk_Invoice")
            }
            .store(in: &cancellables)
    }

    private func sharePDF(data: Data, prefix: String) {
        let fileName = "\(prefix)_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            exportShareURL = url
        } catch {
            exportAlertMessage = "Unable to prepare PDF for sharing."
        }
    }

    private func loadFilterData() {
        isLoadingFilters = true

        Publishers.Zip(
            service.fetchStaffList(),
            service.fetchSellerList(page: 1)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoadingFilters = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] staffResponse, sellerResponse in
            self?.staffList = staffResponse.data
            self?.sellerList = sellerResponse.data.sellers
        }
        .store(in: &cancellables)
    }

    private func loadOrders(reset: Bool) {
        if reset {
            currentOrderPage = 1
            lastOrderPage = 1
            isLoadingOrders = true
        } else {
            isLoadingMoreOrders = true
        }

        service.fetchOrders(
            page: currentOrderPage,
            date: selectedDate,
            staffId: selectedStaffId,
            sellerId: selectedSellerId,
            orderStatus: selectedOrderStatus
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoadingOrders = false
            self.isLoadingMoreOrders = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            let page = response.data.ordersPage
            self.lastOrderPage = max(page.lastPage, 1)
            if reset {
                self.orders = page.orders
            } else {
                self.orders.append(contentsOf: page.orders)
            }
            if self.currentOrderPage <= self.lastOrderPage {
                self.currentOrderPage += 1
            }
        }
        .store(in: &cancellables)
    }
}
