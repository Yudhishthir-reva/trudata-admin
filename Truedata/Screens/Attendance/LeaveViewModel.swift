//
//  LeaveViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class LeaveViewModel: ObservableObject {

    @Published var items: [LeaveItem] = []
    @Published var selectedTab: AttendanceRequestTab = .pending
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: LeaveServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(service: LeaveServiceManager = LeaveServiceManager()) {
        self.service = service
    }

    var filteredItems: [LeaveItem] {
        items.filter { $0.status.caseInsensitiveCompare(selectedTab.rawValue) == .orderedSame }
    }

    func load() {
        isLoading = true
        errorMessage = nil

        service.fetchLeaveList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.items = response.data
            }
            .store(in: &cancellables)
    }
}
