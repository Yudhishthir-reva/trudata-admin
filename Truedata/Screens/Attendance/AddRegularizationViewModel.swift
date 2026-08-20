//
//  AddRegularizationViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class AddRegularizationViewModel: ObservableObject {

    @Published var showSuccessAlert = false
    @Published var successMessage: String?
    @Published var dateToCorrect = ""
    @Published var reason = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let service: RegularizationServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(service: RegularizationServiceManager = RegularizationServiceManager()) {
        self.service = service
    }

    var canSubmit: Bool {
        !dateToCorrect.isEmpty && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(onSuccess: @escaping () -> Void) {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        service.applyRegularization(
            date: dateToCorrect,
            remark: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status {
                self.successMessage = response.message.isEmpty
                    ? "Regularization applied successfully"
                    : response.message
                self.showSuccessAlert = true
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmpty
                    ? "Unable to apply regularization."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
