//
//  SalesmanActivitiesViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class SalesmanActivitiesViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var staffMembers: [SalesmanStaffMember] = []

    private let service = SalesmanActivitiesServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func loadStaff(isRefresh: Bool = false) {
        isLoading = staffMembers.isEmpty || isRefresh
        errorMessage = nil

        service.getStaffList()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.staffMembers.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false

                guard response.status else {
                    if self.staffMembers.isEmpty {
                        self.errorMessage = response.message.isEmptyString
                            ? "Failed to load staff"
                            : response.message
                    }
                    return
                }

                self.staffMembers = response.data.filter(\.isSalesmanEligible)
                self.errorMessage = nil
            }
            .store(in: &cancellables)
    }
}
