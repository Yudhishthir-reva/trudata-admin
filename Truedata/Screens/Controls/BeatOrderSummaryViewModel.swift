//
//  BeatOrderSummaryViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class BeatOrderSummaryViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var summaryData: BeatOrderSummaryResponse?
    @Published var filters = BeatSummaryFilters.initialToday()
    @Published var beatOptions: [BeatSummaryBeatOption] = []
    @Published var staffMembers: [RegisteredStaffMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showFilterSheet = false

    private let service = BeatOrderSummaryServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: AnyCancellable?

    var filteredBeats: [BeatSummaryItem] {
        let beats = summaryData?.beatWiseSummary ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return beats }

        return beats.filter { beat in
            beat.beatName.localizedCaseInsensitiveContains(query)
                || beat.city.localizedCaseInsensitiveContains(query)
                || beat.state.localizedCaseInsensitiveContains(query)
                || beat.placedOrders.orderIds.contains { $0.localizedCaseInsensitiveContains(query) }
                || beat.staffWiseBreakdown.contains { staff in
                    staff.staffName.localizedCaseInsensitiveContains(query)
                        || staff.orderIds.contains { $0.localizedCaseInsensitiveContains(query) }
                }
        }
    }

    var dateSubtitle: String {
        BeatSummaryDateFormatter.displayRange(start: filters.startDate, end: filters.endDate)
    }

    func load(reset: Bool = true) {
        if reset { isLoading = summaryData == nil }
        errorMessage = nil

        fetchTask?.cancel()
        fetchTask = service.fetchSummary(
            startDate: filters.startDate,
            endDate: filters.endDate,
            beatId: filters.beatId,
            staffId: filters.staffId
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            if case .failure(let error) = completion, self.summaryData == nil {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            if response.status {
                self.summaryData = response
                self.errorMessage = nil
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load beat order summary."
                    : response.message
            }
        }
    }

    func loadSupportingDataIfNeeded() {
        guard beatOptions.isEmpty || staffMembers.isEmpty else { return }

        service.fetchAllAreas()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, response.status else { return }
                self.beatOptions = response.states.flatMap { state in
                    state.cities.flatMap { city in
                        city.beats.map { beat in
                            BeatSummaryBeatOption(
                                id: String(beat.id),
                                displayName: "\(beat.name) (\(city.name))"
                            )
                        }
                    }
                }
            }
            .store(in: &cancellables)

        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, response.status else { return }
                self.staffMembers = response.data
            }
            .store(in: &cancellables)
    }

    func applyFilters(_ updated: BeatSummaryFilters) {
        filters = updated
        load(reset: true)
    }

    func resetFilters() {
        filters = BeatSummaryFilters.initialToday()
        load(reset: true)
    }

    func applyDatePreset(_ preset: AchievementHistoryDatePreset) {
        guard preset != .custom,
              let range = AchievementHistoryDatePreset.dateRange(for: preset) else { return }
        filters.datePreset = preset
        filters.startDate = range.start
        filters.endDate = range.end
        load(reset: true)
    }
}

enum BeatSummaryDateFormatter {
    private static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func displayRange(start: String, end: String) -> String {
        let startText = formatted(start) ?? start
        let endText = formatted(end) ?? end
        return "\(startText) - \(endText)"
    }

    private static func formatted(_ value: String) -> String? {
        guard let date = inputFormatter.date(from: value) else { return nil }
        return displayFormatter.string(from: date)
    }
}
