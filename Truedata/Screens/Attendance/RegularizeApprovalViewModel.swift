//
//  RegularizeApprovalViewModel.swift
//  Truedata
//

import Combine
import Foundation

@MainActor
final class RegularizeApprovalViewModel: ObservableObject {

    @Published var items: [RegularizeTeamWiseItem] = []
    @Published var selectedTab: AttendanceRequestTab = .pending
    @Published var isLoading = false
    @Published var isUpdating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service = RegularizeApprovalServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredItems: [RegularizeTeamWiseItem] {
        items.filter { $0.statusTab == selectedTab }
    }

    func load() {
        isLoading = true
        errorMessage = nil

        service.fetchRegularizeTeamWiseList()
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
                        ? "Failed to load regularization requests."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func updateStatus(_ action: RegularizeStatusAction) {
        isUpdating = true

        service.updateRegularizeStatus(
            regularizeId: action.regularizeId,
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
                    ? "Regularization status updated."
                    : response.message
                self.load()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to update regularization status."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
