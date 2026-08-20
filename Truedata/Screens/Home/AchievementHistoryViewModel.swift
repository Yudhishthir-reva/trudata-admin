//
//  AchievementHistoryViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class AchievementHistoryViewModel: ObservableObject {

    @Published var startDate: String
    @Published var endDate: String
    @Published var selectedDatePreset: AchievementHistoryDatePreset = .today
    @Published var viewMode: AchievementHistoryViewMode = .report
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var data: AchievementHistoryData = .empty

    private let service = AchievementHistoryServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedOnce = false

    init(startDate: String, endDate: String) {
        let today = DashboardDateFormat.todayString
        self.startDate = startDate.isEmptyString ? today : startDate
        self.endDate = endDate.isEmptyString ? today : endDate
        self.selectedDatePreset = Self.matchingPreset(startDate: self.startDate, endDate: self.endDate) ?? .custom
    }

    func load(isRefresh: Bool = false) {
        if !isRefresh || !hasLoadedOnce {
            isLoading = true
        }
        errorMessage = nil

        service.fetchAchievementHistory(startDate: startDate, endDate: endDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.hasLoadedOnce = true
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.data = response.parsedData
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load achievement insights."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func applyDatePreset(_ preset: AchievementHistoryDatePreset) {
        guard preset != .custom,
              let range = AchievementHistoryDatePreset.dateRange(for: preset) else { return }
        selectedDatePreset = preset
        startDate = range.start
        endDate = range.end
        load()
    }

    func updateStartDate(_ value: String) {
        startDate = value
        selectedDatePreset = .custom
        load()
    }

    func updateEndDate(_ value: String) {
        endDate = value
        selectedDatePreset = .custom
        load()
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
