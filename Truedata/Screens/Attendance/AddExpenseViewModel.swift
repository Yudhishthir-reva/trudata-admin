//
//  AddExpenseViewModel.swift
//  Truedata
//

import Foundation
import Combine
import PhotosUI
import _PhotosUI_SwiftUI

@MainActor
final class AddExpenseViewModel: ObservableObject {

    @Published var expenseDate = AttendanceAPIDateFormat.string(from: Date())
    @Published var amount = ""
    @Published var remark = ""
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var imageData: Data?
    @Published var isSubmitting = false
    @Published var showSuccessAlert = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service = ExpenseServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var canSubmit: Bool {
        !expenseDate.isEmptyString
            && !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    func loadSelectedImage() {
        guard let selectedPhotoItem else {
            imageData = nil
            return
        }

        Task {
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.imageData = data
                }
            }
        }
    }

    func clearImage() {
        selectedPhotoItem = nil
        imageData = nil
    }

    func submit(onSuccess: @escaping () -> Void) {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        service.addExpense(
            expenseDate: expenseDate,
            amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSubmitting = false
            if response.status {
                self.successMessage = response.message.isEmptyString
                    ? "Expense added successfully."
                    : response.message
                self.showSuccessAlert = true
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to add expense."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
