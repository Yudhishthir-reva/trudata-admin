//
//  RearrangeSellersViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class RearrangeSellersViewModel: ObservableObject {

    @Published var sellers: [StartNewOrderSeller]
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSaveSuccessfully = false

    private let beatId: Int
    private let service = StartNewOrderServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(beatId: Int, sellers: [StartNewOrderSeller]) {
        self.beatId = beatId
        self.sellers = sellers
    }

    func move(from source: IndexSet, to destination: Int) {
        sellers.move(fromOffsets: source, toOffset: destination)
    }

    func saveOrder() {
        guard !sellers.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let sellerIds = sellers.map(\.id)
        service.rearrangeSellers(beatId: beatId, sellerIds: sellerIds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSaving = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.didSaveSuccessfully = true
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to rearrange sellers"
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
