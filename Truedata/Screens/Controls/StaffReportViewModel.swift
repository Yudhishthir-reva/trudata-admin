//
//  StaffReportViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class StaffReportViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var staffMembers: [SalesmanStaffMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = StaffReportServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredMembers: [SalesmanStaffMember] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return staffMembers }
        return staffMembers.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func load(isRefresh: Bool = false) {
        isLoading = staffMembers.isEmpty || isRefresh
        errorMessage = nil

        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
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
                            ? "Failed to load staff reports."
                            : response.message
                    }
                    return
                }

                self.staffMembers = response.data
                self.errorMessage = nil
            }
            .store(in: &cancellables)
    }
}
