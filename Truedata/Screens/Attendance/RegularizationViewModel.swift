//
//  RegularizationViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class RegularizationViewModel: ObservableObject {

    @Published var items: [RegularizationItem] = []
    @Published var selectedTab: AttendanceRequestTab = .pending
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RegularizationServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(service: RegularizationServiceManager = RegularizationServiceManager()) {
        self.service = service
    }

    var filteredItems: [RegularizationItem] {
        items.filter { $0.status.caseInsensitiveCompare(selectedTab.rawValue) == .orderedSame }
    }

    func load() {
        isLoading = true
        errorMessage = nil

        service.fetchRegularizationList()
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
