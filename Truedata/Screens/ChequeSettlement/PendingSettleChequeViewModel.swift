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
    private var loadCancellable: AnyCancellable?
    private var currentPage = 1
    private var isRefreshing = false

    var chequeCount: Int {
        sellers.reduce(0) { $0 + $1.chequeCount }
    }

    var totalChequeAmount: Double {
        sellers.reduce(0) { $0 + $1.totalChequeAmount }
    }

    func load(isRefresh: Bool = true) {
        if isRefresh {
            loadCancellable?.cancel()
            isRefreshing = true
            isLoadingMore = false
            currentPage = 1
            hasMore = true
            isLoading = sellers.isEmpty
        } else {
            guard hasMore, !isLoadingMore, !isLoading, !isRefreshing else { return }
            isLoadingMore = true
            currentPage += 1
        }

        errorMessage = nil
        let requestedPage = currentPage
        let refreshRequest = isRefresh

        loadCancellable = service.getPendingSettleCheques(page: requestedPage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if refreshRequest {
                    self.isRefreshing = false
                    self.isLoading = false
                } else {
                    self.isLoadingMore = false
                }
                if case .failure(let error) = completion, self.sellers.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    if !refreshRequest {
                        // Roll back page bump on failure so retry can re-request same page.
                        self.currentPage = max(1, requestedPage - 1)
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if refreshRequest {
                    self.isRefreshing = false
                    self.isLoading = false
                } else {
                    self.isLoadingMore = false
                }

                guard response.status || !response.data.isEmpty || refreshRequest else {
                    if self.sellers.isEmpty {
                        self.errorMessage = response.message.isEmptyString
                            ? "Nothing left to settle"
                            : response.message
                    }
                    self.hasMore = false
                    return
                }

                if refreshRequest || requestedPage <= 1 {
                    self.sellers = response.data
                } else {
                    // Avoid duplicates if the same page is appended twice.
                    let existingIds = Set(self.sellers.map(\.sellerId))
                    let fresh = response.data.filter { !existingIds.contains($0.sellerId) }
                    self.sellers.append(contentsOf: fresh)
                    if response.data.isEmpty {
                        self.hasMore = false
                    }
                }

                self.currentPage = max(requestedPage, response.currentPage)
                // Empty page means end even if API still reports has_more oddly.
                if response.data.isEmpty && requestedPage > 1 {
                    self.hasMore = false
                } else {
                    self.hasMore = response.hasMore
                }
                self.errorMessage = nil
            }
    }

    func loadMoreIfNeeded(current: PendingSettleChequeSeller) {
        guard hasMore, !isLoadingMore, !isLoading, !isRefreshing else { return }
        guard let index = sellers.firstIndex(where: { $0.sellerId == current.sellerId }) else { return }
        guard index >= sellers.count - 3 else { return }
        load(isRefresh: false)
    }
}
