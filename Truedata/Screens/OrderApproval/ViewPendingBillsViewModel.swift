//
//  ViewPendingBillsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class ViewPendingBillsViewModel: ObservableObject {

    let sellerId: Int
    let staffId: Int
    let sellerName: String

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var bills: [PendingPaymentBill] = []
    @Published var paymentStatusMap: [PaymentLookupItem] = []
    @Published var paymentModeMap: [PaymentLookupItem] = []
    @Published var orderStatusMap: [PaymentLookupItem] = []
    @Published var selectedTabIndex = 0

    private let service = ViewPendingBillsServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private var lastPage = 1
    private var canLoadMore = true

    init(sellerId: Int, staffId: Int, sellerName: String) {
        self.sellerId = sellerId
        self.staffId = staffId
        self.sellerName = sellerName
    }

    var screenTitle: String {
        if sellerName.isEmptyString {
            return bills.first?.sellerName.isEmptyString == false
                ? "\(bills.first?.sellerName ?? "Seller")' Bills"
                : "Seller Bills"
        }
        return "\(sellerName)' Bills"
    }

    var statusTabs: [PendingPaymentStatusTab] {
        paymentStatusMap.map { status in
            PendingPaymentStatusTab(
                key: String(status.key),
                label: status.label.capitalized,
                count: bills.filter { $0.paymentStatus == String(status.key) }.count
            )
        }
    }

    var filteredBills: [PendingPaymentBill] {
        guard !statusTabs.isEmpty, selectedTabIndex < statusTabs.count else { return bills }
        let selectedKey = statusTabs[selectedTabIndex].key
        return bills.filter { $0.paymentStatus == selectedKey }
    }

    var pendingTabIndex: Int {
        paymentStatusMap.firstIndex(where: { $0.key == 0 }) ?? 0
    }

    func loadBills(isRefresh: Bool = false) {
        if isRefresh {
            currentPage = 1
            lastPage = 1
            canLoadMore = true
        }

        guard sellerId > 0, staffId > 0 else {
            errorMessage = "Seller or Staff ID is missing.\nCannot load bills."
            return
        }

        isLoading = true
        errorMessage = nil

        service.getPendingPaymentBills(sellerId: sellerId, staffId: staffId, page: currentPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    if self.bills.isEmpty {
                        self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false

                if response.status || !response.data.response.billList.data.isEmpty {
                    let newBills = response.data.response.billList.data
                    if isRefresh || self.currentPage == 1 {
                        self.bills = newBills
                        self.selectedTabIndex = self.pendingTabIndex
                    } else {
                        self.bills.append(contentsOf: newBills)
                    }

                    self.paymentStatusMap = response.data.paymentStatusMap
                    self.paymentModeMap = response.data.paymentModeMap
                    self.orderStatusMap = response.data.orderStatusMap

                    let pagination = response.data.response.billList
                    self.currentPage = pagination.currentPage
                    self.lastPage = pagination.lastPage
                    self.canLoadMore = pagination.currentPage < pagination.lastPage
                    self.errorMessage = nil
                } else {
                    if self.bills.isEmpty {
                        self.errorMessage = response.message.isEmptyString
                            ? "Failed to load bills."
                            : response.message
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentBill: PendingPaymentBill) {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        guard let index = filteredBills.firstIndex(where: { $0.id == currentBill.id }) else { return }
        guard index >= filteredBills.count - 3 else { return }

        isLoadingMore = true
        currentPage += 1

        service.getPendingPaymentBills(sellerId: sellerId, staffId: staffId, page: currentPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingMore = false
                if case .failure = completion {
                    self.currentPage = max(1, self.currentPage - 1)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingMore = false

                let newBills = response.data.response.billList.data
                self.bills.append(contentsOf: newBills)

                let pagination = response.data.response.billList
                self.currentPage = pagination.currentPage
                self.lastPage = pagination.lastPage
                self.canLoadMore = pagination.currentPage < pagination.lastPage
            }
            .store(in: &cancellables)
    }
}
