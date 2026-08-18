//
//  OrderApprovalViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class OrderApprovalViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isApproving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var items: [OrderApprovalItem] = []
    @Published var statusTabs: [OrderApprovalStatusTab] = []
    @Published var selectedTabIndex = 0

    private let service = OrderApprovalServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredItems: [OrderApprovalItem] {
        guard !statusTabs.isEmpty, selectedTabIndex < statusTabs.count else { return items }
        let statusKey = String(statusTabs[selectedTabIndex].key)
        return items.filter { $0.status == statusKey }
    }

    var dynamicTabs: [OrderApprovalStatusTab] {
        statusTabs.map { tab in
            OrderApprovalStatusTab(
                key: tab.key,
                label: tab.label,
                count: items.filter { $0.status == String(tab.key) }.count
            )
        }
    }

    func loadRequests() {
        isLoading = true
        errorMessage = nil

        service.getOrderApprovalList()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status || !response.data.isEmpty {
                    self.items = response.data
                    self.statusTabs = response.statusCount
                    if self.selectedTabIndex >= self.statusTabs.count {
                        self.selectedTabIndex = 0
                    }
                    self.errorMessage = nil
                } else {
                    self.items = []
                    self.statusTabs = response.statusCount
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load order approval requests."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func approveRequest(_ item: OrderApprovalItem) {
        isApproving = true
        errorMessage = nil
        successMessage = nil

        service.approveRequest(id: item.id, status: "1")
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isApproving = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isApproving = false
                if response.status {
                    self.successMessage = response.message.isEmptyString
                        ? "Request approved successfully."
                        : response.message
                    if let approvedIndex = self.statusTabs.firstIndex(where: { $0.key == 1 }) {
                        self.selectedTabIndex = approvedIndex
                    }
                    self.loadRequests()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to approve request."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
