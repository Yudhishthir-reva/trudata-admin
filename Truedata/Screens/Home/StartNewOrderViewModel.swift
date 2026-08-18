//
//  StartNewOrderViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class StartNewOrderViewModel: ObservableObject {

    @Published var isLoadingAreas = false
    @Published var isFindingSellers = false
    @Published var isSavingBeat = false
    @Published var errorMessage: String?

    @Published var states: [OrderInsightsStateArea] = []
    @Published var preference: StartNewOrderAreaPreference?

    @Published var selectedStateId: Int?
    @Published var selectedCityId: Int?
    @Published var selectedBeatId: Int?
    @Published var selectionStep: StartNewOrderSelectionStep = .state
    @Published var isBeatCollapsed = false
    @Published var isManuallyChangingBeat = false

    @Published var stateSearchQuery = ""
    @Published var citySearchQuery = ""
    @Published var beatSearchQuery = ""

    @Published var sellers: [StartNewOrderSeller] = []
    @Published var sellerSearchQuery = ""
    @Published var selectedSellerTab: StartNewOrderSellerTab = .notVisited
    @Published var visibleListLimit = 8
    @Published var isRequestingAccess = false
    @Published var showApprovalSuccess = false

    private let service = StartNewOrderServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var hasAppliedPreference = false

    var canEditStateAndCity: Bool {
        let role = UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return role == "admin" || role == "sales manager"
    }

    var isStateAndCityPrefilled: Bool {
        preference?.selectedState != nil && preference?.selectedCity != nil
    }

    var selectedState: OrderInsightsStateArea? {
        guard let selectedStateId else { return nil }
        return states.first(where: { $0.id == selectedStateId })
    }

    var selectedCity: OrderInsightsCityArea? {
        guard let selectedCityId else { return nil }
        return selectedState?.cities.first(where: { $0.id == selectedCityId })
    }

    var selectedBeat: OrderInsightsBeatArea? {
        guard let selectedBeatId else { return nil }
        return selectedCity?.beats.first(where: { $0.id == selectedBeatId })
    }

    var selectedBeatName: String {
        selectedBeat?.name ?? "Beat"
    }

    var selectedLocationSubtitle: String {
        let city = selectedCity?.name ?? ""
        let state = selectedState?.name ?? ""
        if city.isEmptyString && state.isEmptyString { return "" }
        if city.isEmptyString { return state }
        if state.isEmptyString { return city }
        return "\(city), \(state)"
    }

    var currentSearchQuery: String {
        switch selectionStep {
        case .state: return stateSearchQuery
        case .city: return citySearchQuery
        case .beat: return beatSearchQuery
        }
    }

    var filteredStates: [OrderInsightsStateArea] {
        filterItems(states, query: stateSearchQuery) { $0.name }
    }

    var filteredCities: [OrderInsightsCityArea] {
        filterItems(selectedState?.cities ?? [], query: citySearchQuery) { $0.name }
    }

    var filteredBeats: [OrderInsightsBeatArea] {
        filterItems(selectedCity?.beats ?? [], query: beatSearchQuery) { $0.name }
    }

    var filteredSellers: [StartNewOrderSeller] {
        let query = sellerSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sellers.filter { seller in
            let matchesSearch = query.isEmptyString
                || seller.displayName.lowercased().contains(query)
                || seller.mobile.lowercased().contains(query)
                || seller.name.lowercased().contains(query)
            let matchesTab = selectedSellerTab.matches(seller)
            return matchesSearch && matchesTab
        }
    }

    var sellerTabs: [StartNewOrderSellerTabItem] {
        var tabs: [StartNewOrderSellerTabItem] = [
            .init(tab: .notVisited, count: sellers.filter(\.isNotVisited).count),
            .init(tab: .orderPlaced, count: sellers.filter(\.isOrderPlaced).count),
            .init(tab: .noOrder, count: sellers.filter(\.isNoOrder).count)
        ]
        let unknownCount = sellers.filter(\.isUnknownVisitStatus).count
        if unknownCount > 0 {
            tabs.append(.init(tab: .unknown, count: unknownCount))
        }
        return tabs
    }

    func selectSellerTab(_ tab: StartNewOrderSellerTab) {
        selectedSellerTab = tab
    }

    func initialize() {
        loadAreas()
    }

    func loadAreas() {
        isLoadingAreas = true
        errorMessage = nil

        service.getAllAreas()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingAreas = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.states = response.states
                self.preference = response.preference
                self.applyPreferencesIfNeeded()
            }
            .store(in: &cancellables)
    }

    func updateSearchQuery(_ query: String) {
        switch selectionStep {
        case .state: stateSearchQuery = query
        case .city: citySearchQuery = query
        case .beat: beatSearchQuery = query
        }
        visibleListLimit = 8
    }

    func clearCurrentSearch() {
        updateSearchQuery("")
    }

    func selectState(_ state: OrderInsightsStateArea) {
        selectedStateId = state.id
        selectedCityId = nil
        selectedBeatId = nil
        sellers = []
        clearSearchQueries()
        selectionStep = .city
        isBeatCollapsed = false
    }

    func selectCity(_ city: OrderInsightsCityArea) {
        selectedCityId = city.id
        selectedBeatId = nil
        sellers = []
        clearSearchQueries()
        selectionStep = .beat
        isBeatCollapsed = false
    }

    func selectBeat(_ beat: OrderInsightsBeatArea) {
        selectedBeatId = beat.id
        clearSearchQueries()
        isManuallyChangingBeat = false
        saveBeatAndLoadSellers(beatId: beat.id)
    }

    func changeBeatSelection() {
        isManuallyChangingBeat = true
        selectedBeatId = nil
        sellers = []
        isBeatCollapsed = false
        selectionStep = .beat
        beatSearchQuery = ""
    }

    func resetAreaSelection() {
        selectedStateId = nil
        selectedCityId = nil
        selectedBeatId = nil
        sellers = []
        isBeatCollapsed = false
        isManuallyChangingBeat = true
        selectionStep = .state
        clearSearchQueries()
    }

    func setSelectionStep(_ step: StartNewOrderSelectionStep) {
        switch step {
        case .state:
            guard canEditStateAndCity || !isStateAndCityPrefilled else { return }
            selectionStep = .state
        case .city:
            guard selectedState != nil,
                  canEditStateAndCity || !isStateAndCityPrefilled else { return }
            selectionStep = .city
        case .beat:
            guard selectedCity != nil else { return }
            selectionStep = .beat
        }
    }

    func showMoreItems() {
        visibleListLimit += 8
    }

    func sellerSelected(_ seller: StartNewOrderSeller) {
        // Create Order cart flow will be wired in a follow-up screen.
        errorMessage = "Create Order for \(seller.displayName) will open here."
    }

    func applyReorderedSellers(_ sellers: [StartNewOrderSeller]) {
        self.sellers = sellers
        guard let beatId = selectedBeatId else { return }
        loadSellers(beatId: beatId)
    }

    func requestAccess(for seller: StartNewOrderSeller) {
        guard !isRequestingAccess else { return }

        isRequestingAccess = true
        errorMessage = nil

        service.sendOrderApprovalRequest(sellerId: seller.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isRequestingAccess = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isRequestingAccess = false
                if response.status {
                    self.showApprovalSuccess = true
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to send approval request"
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func resetApprovalSuccess() {
        showApprovalSuccess = false
    }

    private func saveBeatAndLoadSellers(beatId: Int) {
        isSavingBeat = true
        isFindingSellers = true
        errorMessage = nil
        sellers = []

        service.setStaffBeat(beatId: beatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.isSavingBeat = false
                    self?.isFindingSellers = false
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSavingBeat = false
                if response.status {
                    self.isBeatCollapsed = true
                    self.loadSellers(beatId: beatId)
                    self.loadAreas()
                } else {
                    self.isFindingSellers = false
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to save beat selection"
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func loadSellers(beatId: Int) {
        service.getSellersByBeat(beatId: beatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isFindingSellers = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.sellers = response.sellers
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load sellers"
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func applyPreferencesIfNeeded() {
        guard !hasAppliedPreference,
              let preference,
              selectedBeatId == nil else { return }

        let prefStateId = Int(preference.selectedState ?? "")
        let prefCityId = Int(preference.selectedCity ?? "")
        let prefBeatId = Int(preference.selectedBeat ?? "")

        if !canEditStateAndCity, isStateAndCityPrefilled,
           let prefStateId, let prefCityId {
            selectedStateId = prefStateId
            selectedCityId = prefCityId
            selectionStep = .beat
            hasAppliedPreference = true
            if let prefBeatId,
               let beat = selectedCity?.beats.first(where: { $0.id == prefBeatId }) {
                selectBeat(beat)
            }
            return
        }

        if canEditStateAndCity,
           let prefStateId,
           let prefCityId,
           let prefBeatId,
           let state = states.first(where: { $0.id == prefStateId }),
           let city = state.cities.first(where: { $0.id == prefCityId }),
           city.beats.contains(where: { $0.id == prefBeatId }) {
            selectedStateId = prefStateId
            selectedCityId = prefCityId
            selectionStep = .beat
            hasAppliedPreference = true
            if let beat = city.beats.first(where: { $0.id == prefBeatId }) {
                selectBeat(beat)
            }
        } else if canEditStateAndCity, let prefStateId {
            selectedStateId = prefStateId
            selectionStep = prefCityId == nil ? .city : .beat
            if let prefCityId {
                selectedCityId = prefCityId
            }
            hasAppliedPreference = true
        } else {
            hasAppliedPreference = true
        }
    }

    private func clearSearchQueries() {
        stateSearchQuery = ""
        citySearchQuery = ""
        beatSearchQuery = ""
        visibleListLimit = 8
    }

    private func filterItems<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmptyString else { return items }
        return items.filter { name($0).localizedCaseInsensitiveContains(trimmed) }
    }
}
