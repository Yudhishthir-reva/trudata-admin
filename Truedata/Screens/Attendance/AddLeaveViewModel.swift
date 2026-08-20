//
//  AddLeaveViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class AddLeaveViewModel: ObservableObject {

    @Published var leaveTypes: [LeaveTypeItem] = []
    @Published var isLoadingLeaveTypes = false
    @Published var showLeaveTypePicker = false
    @Published var showSuccessAlert = false
    @Published var successMessage: String?

    @Published var fromDate = ""
    @Published var toDate = ""
    @Published var selectedLeaveTypeId = -1
    @Published var selectedLeaveTypeName = ""
    @Published var remark = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let service: LeaveServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(service: LeaveServiceManager = LeaveServiceManager()) {
        self.service = service
    }

    var canSubmit: Bool {
        !fromDate.isEmpty && !toDate.isEmpty && selectedLeaveTypeId > 0
    }

    func loadLeaveTypes() {
        guard leaveTypes.isEmpty, !isLoadingLeaveTypes else { return }

        isLoadingLeaveTypes = true
        service.fetchLeaveTypes()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingLeaveTypes = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.leaveTypes = response.data
            }
            .store(in: &cancellables)
    }

    func selectLeaveType(_ type: LeaveTypeItem) {
        selectedLeaveTypeId = type.id
        selectedLeaveTypeName = type.name
    }

    func submit(onSuccess: @escaping () -> Void) {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        service.applyLeave(
            leaveTypeId: selectedLeaveTypeId,
            startDate: fromDate,
            endDate: toDate,
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    ? "Leave applied successfully"
                    : response.message
                self.showSuccessAlert = true
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmpty
                    ? "Unable to apply leave."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
