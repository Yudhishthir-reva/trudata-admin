//
//  StaffActivitiesViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class StaffActivitiesViewModel: ObservableObject {

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: AchievementHistoryDatePreset = .today
    @Published var staffNameSearch = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published private(set) var activities: [StaffActivityItem] = []

    private let service = StaffActivitiesServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var currentPage = 1
    private var canLoadMore = true

    init(startDate: String = "", endDate: String = "") {
        let today = DashboardDateFormat.todayString
        self.startDate = startDate.isEmptyString ? today : startDate
        self.endDate = endDate.isEmptyString ? today : endDate
        self.selectedDatePreset = Self.matchingPreset(startDate: self.startDate, endDate: self.endDate) ?? .today
    }

    func load(isRefresh: Bool = false) {
        if isRefresh {
            currentPage = 1
            canLoadMore = true
        }

        if isRefresh || activities.isEmpty {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        errorMessage = nil

        service.fetchStaffActivitiesHistory(
            startDate: startDate,
            endDate: endDate,
            staffName: staffNameSearch.trimmingCharacters(in: .whitespacesAndNewlines),
            page: currentPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.activities.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false

            guard response.status, let pageData = response.data else {
                if self.activities.isEmpty {
                    self.errorMessage = response.message.nilIfEmpty ?? "Failed to load staff activities."
                }
                return
            }

            if isRefresh || self.currentPage == 1 {
                self.activities = pageData.activities
            } else {
                self.activities.append(contentsOf: pageData.activities)
            }

            self.canLoadMore = pageData.currentPage < pageData.lastPage
            self.errorMessage = nil
        }
        .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentItem: StaffActivityItem) {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = activities.firstIndex(where: { $0.id == currentItem.id }) else { return }
        guard index >= activities.count - 3 else { return }

        currentPage += 1
        load(isRefresh: false)
    }

    func retry() {
        currentPage = 1
        canLoadMore = true
        activities = []
        load(isRefresh: true)
    }

    func applyDatePreset(_ preset: AchievementHistoryDatePreset) {
        guard preset != .custom,
              let range = AchievementHistoryDatePreset.dateRange(for: preset) else { return }
        selectedDatePreset = preset
        startDate = range.start
        endDate = range.end
        retry()
    }

    func updateStartDate(_ value: String) {
        startDate = value
        selectedDatePreset = .custom
        retry()
    }

    func updateEndDate(_ value: String) {
        endDate = value
        selectedDatePreset = .custom
        retry()
    }

    func updateStaffNameSearch(_ value: String) {
        staffNameSearch = value
        searchCancellable?.cancel()
        searchCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.retry()
            }
    }

    private static func matchingPreset(startDate: String, endDate: String) -> AchievementHistoryDatePreset? {
        for preset in AchievementHistoryDatePreset.selectablePresets {
            guard let range = AchievementHistoryDatePreset.dateRange(for: preset) else { continue }
            if range.start == startDate && range.end == endDate {
                return preset
            }
        }
        return nil
    }
}
