//
//  SellerReportViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class SellerReportViewModel: ObservableObject {

    @Published var sellers: [SellerReportItem] = []
    @Published var total = 0
    @Published var searchText = ""
    @Published var filters = SellerReportFilters.initialToday()
    @Published var staffMembers: [RegisteredStaffMember] = []
    @Published var areas: [OrderInsightsStateArea] = []

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var showFilterSheet = false

    private let service = SellerReportServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var fetchTask: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = false

    func loadInitial() {
        loadSupportingDataIfNeeded()
        fetchSellers(reset: true)
    }

    func refresh() {
        fetchSellers(reset: true)
    }

    func onSearchChanged(_ query: String) {
        searchText = query
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchSellers(reset: true)
            }
    }

    func loadMoreIfNeeded(currentSeller: SellerReportItem) {
        guard let last = sellers.last, last.id == currentSeller.id else { return }
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        fetchSellers(reset: false)
    }

    func applyFilters(_ updated: SellerReportFilters) {
        filters = updated
        fetchSellers(reset: true)
    }

    func resetFilters() {
        filters = .initialToday()
        fetchSellers(reset: true)
    }

    private func loadSupportingDataIfNeeded() {
        if staffMembers.isEmpty {
            service.fetchStaffList()
                .receive(on: DispatchQueue.main)
                .sink { _ in } receiveValue: { [weak self] response in
                    guard let self, response.status else { return }
                    self.staffMembers = response.data
                }
                .store(in: &cancellables)
        }

        if areas.isEmpty {
            service.fetchAllAreas()
                .receive(on: DispatchQueue.main)
                .sink { _ in } receiveValue: { [weak self] response in
                    self?.areas = response.states
                }
                .store(in: &cancellables)
        }
    }

    private func fetchSellers(reset: Bool) {
        if reset {
            currentPage = 1
            canLoadMore = false
            isLoading = sellers.isEmpty
        } else {
            isLoadingMore = true
        }
        errorMessage = nil

        let page = reset ? 1 : currentPage + 1
        fetchTask?.cancel()
        fetchTask = service.fetchRegisteredSellers(
            page: page,
            fromDate: filters.startDate,
            toDate: filters.endDate,
            registeredBy: filters.staffId.nilIfEmpty,
            beatId: filters.beatId.nilIfEmpty,
            search: searchText.nilIfEmpty
        )
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
            if response.status {
                let incoming = response.data.sellers
                self.sellers = reset ? incoming : self.sellers + incoming
                self.total = response.data.total
                self.currentPage = response.data.currentPage
                self.canLoadMore = response.data.hasNextPage
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load seller report."
                    : response.message
            }
        }
    }
}
