//
//  RegisteredSellersViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class RegisteredSellersViewModel: ObservableObject {

    @Published var sellers: [RegisteredSellerItem] = []
    @Published var total = 0
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isApplyingFilters = false
    @Published var errorMessage: String?
    @Published var showDeactBtn = false
    @Published var searchText = ""
    @Published var statusFilter = ""
    @Published var stateId: Int?
    @Published var cityId: Int?
    @Published var beatId: Int?
    @Published var stateName: String?
    @Published var cityName: String?
    @Published var beatName: String?
    @Published var areas: [OrderInsightsStateArea] = []
    @Published var isLoadingAreas = false
    @Published var statusUpdateSellerId: Int?
    @Published var isUpdatingStatus = false

    private let service: RegisteredSellersServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true

    init(service: RegisteredSellersServiceManager = RegisteredSellersServiceManager()) {
        self.service = service
    }

    var hasActiveFilters: Bool {
        stateId != nil || cityId != nil || beatId != nil || !statusFilter.isEmptyString
    }

    func loadInitial() {
        loadAreasIfNeeded()
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

    func loadMoreIfNeeded(currentSeller: RegisteredSellerItem) {
        guard let last = sellers.last, last.id == currentSeller.id else { return }
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        fetchSellers(reset: false)
    }

    func applyFilters(
        stateId: Int?,
        cityId: Int?,
        beatId: Int?,
        status: String,
        stateName: String?,
        cityName: String?,
        beatName: String?
    ) {
        self.stateId = stateId
        self.cityId = cityId
        self.beatId = beatId
        self.statusFilter = status
        self.stateName = stateName
        self.cityName = cityName
        self.beatName = beatName
        isApplyingFilters = true
        fetchSellers(reset: true)
    }

    func resetFilters() {
        stateId = nil
        cityId = nil
        beatId = nil
        statusFilter = ""
        stateName = nil
        cityName = nil
        beatName = nil
        isApplyingFilters = true
        fetchSellers(reset: true)
    }

    func prepareStatusUpdate(for seller: RegisteredSellerItem) -> (title: String, message: String) {
        statusUpdateSellerId = seller.id
        let action = seller.isActive ? "Deactivate" : "Activate"
        return (
            "\(action) \(seller.name)?",
            "Are you sure you want to \(action.lowercased()) this seller?"
        )
    }

    func confirmStatusUpdate() {
        guard let sellerId = statusUpdateSellerId else { return }
        let seller = sellers.first(where: { $0.id == sellerId })
        let newStatus = (seller?.isActive == true) ? 0 : 1
        isUpdatingStatus = true

        service.updateSellerStatus(sellerId: sellerId, status: newStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isUpdatingStatus = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.statusUpdateSellerId = nil
                if response.status {
                    self.fetchSellers(reset: true)
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to update seller status." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func cancelStatusUpdate() {
        statusUpdateSellerId = nil
    }

    private func loadAreasIfNeeded() {
        guard areas.isEmpty, !isLoadingAreas else { return }
        isLoadingAreas = true
        service.fetchAllAreas()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingAreas = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.areas = response.states
                let hadFilters = self?.hasActiveFilters ?? false
                self?.applyDefaultFiltersFromPreference(response.preference)
                if !hadFilters && (self?.hasActiveFilters == true) {
                    self?.fetchSellers(reset: true)
                }
            }
            .store(in: &cancellables)
    }

    private func applyDefaultFiltersFromPreference(_ preference: StartNewOrderAreaPreference?) {
        guard let preference else { return }
        if stateId == nil,
           let stateName = preference.selectedState,
           let state = areas.first(where: { $0.name == stateName }) {
            stateId = state.id
            self.stateName = state.name
        }
        if cityId == nil,
           let cityName = preference.selectedCity,
           let stateId,
           let city = areas.first(where: { $0.id == stateId })?.cities.first(where: { $0.name == cityName }) {
            cityId = city.id
            self.cityName = city.name
        }
        if beatId == nil,
           let beatName = preference.selectedBeat,
           let cityId,
           let beat = areas.flatMap(\.cities).first(where: { $0.id == cityId })?.beats.first(where: { $0.name == beatName }) {
            beatId = beat.id
            self.beatName = beat.name
        }
    }

    private func fetchSellers(reset: Bool) {
        if reset {
            currentPage = 1
            canLoadMore = true
            if !isApplyingFilters {
                isLoading = sellers.isEmpty
            }
        } else {
            isLoadingMore = true
        }
        errorMessage = nil

        service.fetchSellerList(
            page: currentPage,
            stateId: stateId.map(String.init),
            cityId: cityId.map(String.init),
            beatId: beatId.map(String.init),
            status: statusFilter.isEmptyString ? nil : statusFilter,
            shopName: searchText.isEmptyString ? nil : searchText
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            self.isApplyingFilters = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status {
                let incoming = response.data.sellers
                self.sellers = reset ? incoming : self.sellers + incoming
                self.total = response.data.total
                self.showDeactBtn = response.showDeactBtn
                self.canLoadMore = response.data.currentPage < response.data.lastPage
                if self.canLoadMore {
                    self.currentPage += 1
                }
            } else {
                self.errorMessage = response.message.isEmptyString ? "Unable to load sellers." : response.message
            }
        }
        .store(in: &cancellables)
    }
}
