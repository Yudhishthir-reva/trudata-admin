//
//  ExpenseViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ExpenseViewModel: ObservableObject {

    @Published var items: [ExpenseItem] = []
    @Published var selectedTab: AttendanceRequestTab = .pending
    @Published var isLoading = false
    @Published var isUpdating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service = ExpenseServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredItems: [ExpenseItem] {
        items.filter { $0.statusTab == selectedTab }
    }

    func load() {
        isLoading = true
        errorMessage = nil

        service.fetchAllExpensesList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.items = response.data
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load expenses."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func updateStatus(_ action: ExpenseStatusAction) {
        isUpdating = true
        service.updateExpenseStatus(
            expenseId: action.expenseId,
            status: action.statusValue,
            staffId: action.staffId
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isUpdating = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isUpdating = false
            if response.status {
                self.successMessage = response.message.isEmptyString
                    ? "Expense status updated."
                    : response.message
                self.load()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to update expense status."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
