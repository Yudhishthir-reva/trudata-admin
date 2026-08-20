//
//  SalesmanActivityDetailViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class SalesmanActivityDetailViewModel: ObservableObject {

    let staffId: String
    let staffName: String

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var allShops: [SalesmanAllShop] = []
    @Published var activities = SalesmanActivitiesData(
        shopsVisited: [],
        shopsGivenOrders: [],
        shopsNotGivenOrders: [],
        ordersPhysical: [],
        ordersTelephonic: []
    )

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: OrderInsightsDatePreset = .thisYear
    @Published var isDateFilterExpanded = false
    @Published var selectedTab: SalesmanActivityTab = .summary
    @Published var selectedBeat: String?
    @Published var shopSearch = ""
    @Published var shopOrderFilter: SalesmanShopOrderFilter = .all

    private let service = SalesmanActivitiesServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(staffId: String, staffName: String) {
        self.staffId = staffId
        self.staffName = staffName

        if let range = OrderInsightsDatePreset.dateRange(for: .thisYear) {
            startDate = range.start
            endDate = range.end
        } else {
            let today = OrderInsightsDateFormat.todayString
            startDate = today
            endDate = today
        }
    }

    var screenTitle: String {
        "\(staffName) Activities"
    }

    var availableBeats: [String] {
        var beats = Set<String>()
        allShops.forEach { beats.insert($0.resolvedBeatName) }
        activities.shopsVisited.forEach { beats.insert($0.resolvedBeatName) }
        activities.shopsGivenOrders.forEach { beats.insert($0.resolvedBeatName) }
        activities.shopsNotGivenOrders.forEach { beats.insert($0.resolvedBeatName) }
        activities.ordersPhysical.forEach { beats.insert($0.resolvedBeatName) }
        activities.ordersTelephonic.forEach { beats.insert($0.resolvedBeatName) }
        return beats.filter { $0 != "Unassigned Beat" }.sorted()
    }

    var conversionPercent: Int {
        let visits = activities.shopsVisited.count
        guard visits > 0 else { return 0 }
        return Int((Double(activities.shopsGivenOrders.count) / Double(visits)) * 100)
    }

    var assignedShopsTitle: String {
        selectedDatePreset == .today ? "Today's Assigned Shops" : "Assigned Shops"
    }

    var filteredAssignedShops: [SalesmanAllShop] {
        allShops.filter { shop in
            let matchesBeat = selectedBeat == nil || shop.resolvedBeatName == selectedBeat
            let matchesSearch = shopSearch.isEmptyString
                || shop.shopName.localizedCaseInsensitiveContains(shopSearch)
            let matchesFilter: Bool
            switch shopOrderFilter {
            case .all: matchesFilter = true
            case .placed: matchesFilter = shop.isOrderPlaced
            case .notPlaced: matchesFilter = !shop.isOrderPlaced
            }
            return matchesBeat && matchesSearch && matchesFilter
        }
    }

    var groupedAssignedShops: [(beat: String, shops: [SalesmanAllShop])] {
        Dictionary(grouping: filteredAssignedShops, by: \.resolvedBeatName)
            .map { ($0.key, $0.value) }
            .sorted { $0.beat < $1.beat }
    }

    func tabTitle(for tab: SalesmanActivityTab) -> String {
        switch tab {
        case .summary: return "Summary"
        case .visits: return "Visits (\(activities.shopsVisited.count))"
        case .orders: return "Orders (\(activities.shopsGivenOrders.count))"
        case .noOrders: return "No Orders Visits (\(activities.shopsNotGivenOrders.count))"
        case .field: return "Field (\(activities.ordersPhysical.count))"
        case .phone: return "Phone (\(activities.ordersTelephonic.count))"
        }
    }

    func groupedShopsVisited() -> [(beat: String, shops: [SalesmanShopInfo])] {
        groupedByBeat(activities.shopsVisited.filter(beatMatches))
    }

    func groupedShopsNotGivenOrders() -> [(beat: String, shops: [SalesmanShopInfo])] {
        groupedByBeat(activities.shopsNotGivenOrders.filter(beatMatches))
    }

    func groupedOrders() -> [(beat: String, orders: [SalesmanOrderInfo])] {
        Dictionary(grouping: activities.shopsGivenOrders.filter(beatMatches), by: \.resolvedBeatName)
            .map { ($0.key, $0.value) }
            .sorted { $0.beat < $1.beat }
    }

    func loadActivities(isRefresh: Bool = false) {
        isLoading = isRefresh || allShops.isEmpty
        errorMessage = nil

        service.getSalesmanActivities(
            staffId: staffId,
            startDate: startDate,
            endDate: endDate
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            if case .failure(let error) = completion, self.allShops.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false

            guard response.status else {
                if self.allShops.isEmpty {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load activities"
                        : response.message
                }
                return
            }

            self.allShops = response.allShops
            self.activities = response.activities ?? SalesmanActivitiesData(
                shopsVisited: [],
                shopsGivenOrders: [],
                shopsNotGivenOrders: [],
                ordersPhysical: [],
                ordersTelephonic: []
            )
            self.errorMessage = nil
        }
        .store(in: &cancellables)
    }

    func applyDatePreset(_ preset: OrderInsightsDatePreset) {
        selectedDatePreset = preset
        guard preset != .custom,
              let range = OrderInsightsDatePreset.dateRange(for: preset) else { return }
        startDate = range.start
        endDate = range.end
        loadActivities(isRefresh: true)
    }

    func updateStartDate(_ value: String) {
        startDate = OrderInsightsDateFormat.normalizedAPIString(from: value)
        selectedDatePreset = .custom
        loadActivities(isRefresh: true)
    }

    func updateEndDate(_ value: String) {
        endDate = OrderInsightsDateFormat.normalizedAPIString(from: value)
        selectedDatePreset = .custom
        loadActivities(isRefresh: true)
    }

    private func beatMatches<T>(_ item: T) -> Bool where T: BeatNameProviding {
        selectedBeat == nil || item.resolvedBeatName == selectedBeat
    }

    private func groupedByBeat(_ shops: [SalesmanShopInfo]) -> [(beat: String, shops: [SalesmanShopInfo])] {
        Dictionary(grouping: shops, by: \.resolvedBeatName)
            .map { ($0.key, $0.value) }
            .sorted { $0.beat < $1.beat }
    }
}

private protocol BeatNameProviding {
    var resolvedBeatName: String { get }
}

extension SalesmanShopInfo: BeatNameProviding {}
extension SalesmanOrderInfo: BeatNameProviding {}
extension SalesmanPhysicalOrder: BeatNameProviding {}
extension SalesmanTelephonicOrder: BeatNameProviding {}
