//
//  ApproveBillsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class ApproveBillsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isApproving = false
    @Published var errorMessage: String?
    @Published var bills: [PendingBillItem] = []
    @Published var successMessage: String?

    private let service = ApproveBillsServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func loadPendingBills() {
        isLoading = true
        errorMessage = nil

        service.getPendingBills()
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
                if response.success || !response.data.isEmpty {
                    self.bills = response.data
                    self.errorMessage = nil
                } else {
                    self.bills = []
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load pending bills."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func approveBill(_ bill: PendingBillItem) {
        isApproving = true
        errorMessage = nil
        successMessage = nil

        service.approveBill(billId: bill.id, status: 1)
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
                        ? "Bill approved successfully."
                        : response.message
                    self.loadPendingBills()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to approve bill."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
