//
//  ChangeSellerViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class ChangeSellerViewModel: ObservableObject {

    let orderId: String
    let currentSellerId: Int

    @Published private(set) var currentSellerDisplay: String

    @Published var areaStates: [OrderInsightsStateArea] = []
    @Published var selectedStateId: String?
    @Published var selectedCityId: String?
    @Published var selectedBeatId: String?
    @Published private(set) var sellerCurrentPage = 1
    @Published private(set) var sellerLastPage = 1
    @Published var sellerSearch = ""
    @Published var sellerList: [OrderInsightsSellerItem] = []
    @Published var selectedSellerId: String?
    @Published var isLoadingAreas = false
    @Published var isLoadingSellers = false
    @Published var isLoadingMoreSellers = false
    @Published var isUpdating = false
    @Published var errorMessage: String?
    @Published var didUpdateSuccessfully = false

    private let service = OrderDetailServiceManager()
    private let sellerProfileService = SellerProfileServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?

    init(order: OrderDetailData, orderId: String) {
        self.orderId = orderId
        self.currentSellerId = order.sellerId
        self.currentSellerDisplay = order.changeSellerDisplayName
    }

    var selectedState: OrderInsightsStateArea? {
        guard let selectedStateId, let id = Int(selectedStateId) else { return nil }
        return areaStates.first(where: { $0.id == id })
    }

    var selectedCity: OrderInsightsCityArea? {
        guard let selectedCityId, let id = Int(selectedCityId) else { return nil }
        return selectedState?.cities.first(where: { $0.id == id })
    }

    var canUpdateSeller: Bool {
        guard let selectedSellerId, let sellerId = Int(selectedSellerId), sellerId > 0 else { return false }
        return sellerId != currentSellerId && !isUpdating
    }

    var canLoadMoreSellers: Bool {
        sellerCurrentPage < sellerLastPage
    }

    var displayableSellerList: [OrderInsightsSellerItem] {
        sellerList.filter(\.isSelectable)
    }

    var canBrowseSellers: Bool {
        selectedStateId != nil && selectedCityId != nil
    }

    func initialize() {
        resolveCurrentSellerDisplayIfNeeded()
        loadAreas()
    }

    private func resolveCurrentSellerDisplayIfNeeded() {
        guard currentSellerDisplay == "N/A" || currentSellerDisplay.isEmptyString else { return }
        guard currentSellerId > 0 else { return }

        service.getOrderDetail(orderId: orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.loadSellerProfileFallback()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let display = response.data.changeSellerDisplayName
                if display != "N/A", !display.isEmptyString {
                    self.currentSellerDisplay = display
                } else {
                    self.loadSellerProfileFallback()
                }
            }
            .store(in: &cancellables)
    }

    private func loadSellerProfileFallback() {
        guard currentSellerDisplay == "N/A" || currentSellerDisplay.isEmptyString else { return }

        let today = SellerProfileDateFormat.apiFormatter.string(from: Date())
        sellerProfileService.getSellerProfile(
            sellerId: String(currentSellerId),
            startDate: today,
            endDate: today
        )
        .receive(on: RunLoop.main)
        .sink { _ in } receiveValue: { [weak self] response in
            guard let self, let profile = response.data?.profile else { return }
            let display = OrderDetailData.formatSellerDisplay(
                shop: profile.shopName,
                name: profile.name,
                mobile: profile.mobile,
                address: profile.address,
                sellerId: self.currentSellerId
            )
            if display != "N/A", !display.isEmptyString {
                self.currentSellerDisplay = display
            }
        }
        .store(in: &cancellables)
    }

    func loadAreas() {
        isLoadingAreas = true
        errorMessage = nil

        service.getAreas()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoadingAreas = false
                if case .failure(let error) = completion {
                    self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingAreas = false
                if response.status {
                    self.areaStates = response.states
                    self.applyAreaPreference(response.preference)
                    if self.canBrowseSellers {
                        self.loadSellers(isRefresh: true)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadSellers(isRefresh: Bool) {
        guard canBrowseSellers else {
            if isRefresh {
                sellerList = []
                selectedSellerId = nil
            }
            return
        }

        if isRefresh {
            sellerCurrentPage = 1
            sellerLastPage = 1
            isLoadingSellers = true
        } else {
            guard sellerCurrentPage < sellerLastPage else { return }
            isLoadingMoreSellers = true
            sellerCurrentPage += 1
        }

        let query = sellerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        service.getSellerList(
            page: sellerCurrentPage,
            stateId: selectedStateId,
            cityId: selectedCityId,
            beatId: selectedBeatId,
            shopName: query.isEmptyString ? nil : query
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            self?.isLoadingSellers = false
            self?.isLoadingMoreSellers = false
            if case .failure(let error) = completion {
                self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoadingSellers = false
            self.isLoadingMoreSellers = false
            guard response.status else { return }

            let sellers = response.data.sellers.filter(\.isSelectable)
            if isRefresh {
                self.sellerList = sellers
                if let selectedSellerId,
                   !sellers.contains(where: { String($0.id) == selectedSellerId }) {
                    self.selectedSellerId = nil
                }
            } else {
                self.sellerList.append(contentsOf: sellers)
            }
            self.sellerCurrentPage = response.data.currentPage
            self.sellerLastPage = response.data.lastPage
        }
        .store(in: &cancellables)
    }

    func updateSearchQuery(_ query: String) {
        sellerSearch = query
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadSellers(isRefresh: true)
            }
    }

    func selectState(_ stateId: String?) {
        selectedStateId = stateId
        selectedCityId = nil
        selectedBeatId = nil
        selectedSellerId = nil
        sellerList = []
        if stateId != nil {
            // Wait for city selection before loading sellers.
        }
    }

    func selectCity(_ cityId: String?) {
        selectedCityId = cityId
        selectedBeatId = nil
        selectedSellerId = nil
        sellerList = []
        if cityId != nil {
            loadSellers(isRefresh: true)
        }
    }

    func selectBeat(_ beatId: String?) {
        selectedBeatId = beatId
        loadSellers(isRefresh: true)
    }

    func updateSeller() {
        guard let selectedSellerId, let sellerId = Int(selectedSellerId), sellerId > 0 else {
            errorMessage = "Please select a seller."
            return
        }

        isUpdating = true
        errorMessage = nil

        service.updateOrderSeller(orderId: orderId, sellerId: sellerId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isUpdating = false
                if case .failure(let error) = completion {
                    self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdating = false
                if response.status {
                    self.didUpdateSuccessfully = true
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to update seller."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func applyAreaPreference(_ preference: StartNewOrderAreaPreference?) {
        guard let preference else { return }

        if let stateName = preference.selectedState,
           let state = areaStates.first(where: { $0.name.caseInsensitiveCompare(stateName) == .orderedSame }) {
            selectedStateId = String(state.id)

            if let cityName = preference.selectedCity,
               let city = state.cities.first(where: { $0.name.caseInsensitiveCompare(cityName) == .orderedSame }) {
                selectedCityId = String(city.id)

                if let beatName = preference.selectedBeat,
                   let beat = city.beats.first(where: { $0.name.caseInsensitiveCompare(beatName) == .orderedSame }) {
                    selectedBeatId = String(beat.id)
                }
            }
        }
    }
}
