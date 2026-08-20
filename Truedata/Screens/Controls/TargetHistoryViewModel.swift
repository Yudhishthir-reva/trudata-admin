//
//  TargetHistoryViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class TargetHistoryViewModel: ObservableObject {

    @Published var target: TargetHistoryDetails?
    @Published var orders: [TargetHistoryOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = TargetServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func load(targetId: Int) {
        isLoading = orders.isEmpty && target == nil
        errorMessage = nil

        service.fetchTargetHistory(targetId: String(targetId))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.target == nil {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let data = response.data {
                    self.target = data.target
                    self.orders = data.orders
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load target history."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
