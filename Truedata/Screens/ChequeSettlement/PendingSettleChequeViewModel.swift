//
//  PendingSettleChequeViewModel.swift
//  Truedata
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class PendingSettleChequeViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var sellers: [PendingSettleChequeSeller] = []
    @Published var hasMore = true

    private let service = ChequeSettlementServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1

    var chequeCount: Int {
        sellers.reduce(0) { $0 + $1.chequeCount }
    }

    var totalChequeAmount: Double {
        sellers.reduce(0) { $0 + $1.totalChequeAmount }
    }

    func load(isRefresh: Bool = true) {
        if isRefresh {
            currentPage = 1
            hasMore = true
            isLoading = sellers.isEmpty
        } else {
            guard hasMore, !isLoadingMore, !isLoading else { return }
            isLoadingMore = true
            currentPage += 1
        }

        errorMessage = nil

        service.getPendingSettleCheques(page: currentPage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                if case .failure(let error) = completion, self.sellers.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false

                if response.status || !response.data.isEmpty {
                    if isRefresh || self.currentPage == 1 {
                        self.sellers = response.data
                    } else {
                        self.sellers.append(contentsOf: response.data)
                    }
                    self.currentPage = response.currentPage
                    self.hasMore = response.hasMore
                    self.errorMessage = nil
                } else if self.sellers.isEmpty {
                    self.errorMessage = response.message.isEmptyString
                        ? "Nothing left to settle"
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func loadMoreIfNeeded(current: PendingSettleChequeSeller) {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard let index = sellers.firstIndex(where: { $0.sellerId == current.sellerId }) else { return }
        guard index >= sellers.count - 3 else { return }
        load(isRefresh: false)
    }
}
