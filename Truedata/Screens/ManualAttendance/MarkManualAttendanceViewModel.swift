//
//  MarkManualAttendanceViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

/// Which rows the list shows.
enum ManualAttendanceStaffFilter: String, CaseIterable, Identifiable {
    case all, unmarked, edited
    var id: String { rawValue }
}

/// `manual-attendance/staff-list` and `/mark`: load a day, change rows locally, then save every
/// change in one bulk call. The server upserts, so a day can be opened and corrected later.
/// Mirrors Android `MarkAttendanceViewModel`.
final class MarkManualAttendanceViewModel: ObservableObject {

    @Published var date: Date
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    /// The server's Sunday message; when set there is no one to mark.
    @Published private(set) var weeklyOff: String?
    @Published private(set) var staff: [ManualAttendanceStaff] = []
    /// What the user picked and has not saved, by user id. Only differences from ``staff`` live here.
    @Published private(set) var draft: [Int: ManualAttendanceType] = [:]
    @Published var query = ""
    @Published var filter: ManualAttendanceStaffFilter = .all
    @Published private(set) var isSaving = false
    @Published var message: String?
    @Published var error: String?

    private let service = ManualAttendanceServiceManager()
    private var loadCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(date: Date = ManualAttendanceDate.today) {
        self.date = ManualAttendanceDate.startOfDay(date)
    }

    // MARK: - Derived state

    func saved(_ userID: Int) -> ManualAttendanceType? {
        ManualAttendanceType(code: staff.first { $0.userID == userID }?.attendanceType)
    }

    func current(_ member: ManualAttendanceStaff) -> ManualAttendanceType? {
        draft[member.userID] ?? ManualAttendanceType(code: member.attendanceType)
    }

    var hasChanges: Bool { !draft.isEmpty }

    /// The pending picks per status, for the save confirmation.
    var changeCounts: [ManualAttendanceType: Int] {
        draft.values.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    var markedCount: Int { staff.filter { current($0) != nil }.count }

    var unmarkedCount: Int { staff.count - markedCount }

    var counts: [ManualAttendanceType: Int] {
        staff.compactMap { current($0) }.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    /// Rows after the search and the filter, in the server's order.
    var visible: [ManualAttendanceStaff] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return staff.filter { member in
            let matches = search.isEmpty
                || member.name.localizedCaseInsensitiveContains(search)
                || (member.designation ?? "").localizedCaseInsensitiveContains(search)
            guard matches else { return false }
            switch filter {
            case .all: return true
            case .unmarked: return current(member) == nil
            case .edited: return draft[member.userID] != nil
            }
        }
    }

    var canMark: Bool { !isLoading && loadError == nil && weeklyOff == nil && !staff.isEmpty }

    // MARK: - Intents

    func changeDate(to newDate: Date) {
        let day = ManualAttendanceDate.startOfDay(newDate)
        guard day != date else { return }
        date = day
        // Cleared, not kept while loading: the old day's marks would read as the new day's.
        staff = []
        weeklyOff = nil
        draft = [:]
        filter = .all
        load()
    }

    func mark(userID: Int, as type: ManualAttendanceType) {
        apply(userID: userID, type: type)
    }

    /// Sets `type` on every row in `userIDs` — the rows on screen when the user tapped it.
    func markAll(_ userIDs: [Int], as type: ManualAttendanceType) {
        userIDs.forEach { apply(userID: $0, type: type) }
    }

    func discardChanges() { draft = [:] }

    /// Puts one row back to what is saved.
    func revert(userID: Int) { draft.removeValue(forKey: userID) }

    /// Picking what is already saved drops the row from the draft rather than re-sending it.
    private func apply(userID: Int, type: ManualAttendanceType) {
        if saved(userID) == type {
            draft.removeValue(forKey: userID)
        } else {
            draft[userID] = type
        }
    }

    // MARK: - Network

    func load() {
        loadCancellable?.cancel()
        let day = date
        isLoading = true
        loadError = nil

        loadCancellable = service.fetchStaffList(date: ManualAttendanceDate.day(day))
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.loadError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self, self.date == day else { return }
                self.isLoading = false
                guard response.status else {
                    self.loadError = response.message.isEmpty
                        ? "Couldn't load the staff list for this day."
                        : response.message
                    return
                }
                self.loadError = nil
                let rows = response.data.staff.filter { $0.userID > 0 }
                let ids = Set(rows.map(\.userID))
                self.weeklyOff = response.data.isWeeklyOff
                    ? (response.data.weeklyOffMessage?.nilIfBlank
                       ?? "This is a weekly off. Attendance can't be marked for it.")
                    : nil
                self.staff = rows
                // A refresh keeps unsaved picks for people still on the list.
                self.draft = self.draft.filter { ids.contains($0.key) }
            }
    }

    func save() {
        guard !isSaving, hasChanges, weeklyOff == nil else { return }
        let day = date
        let marks = draft
        isSaving = true

        service.mark(date: ManualAttendanceDate.day(day), marks: marks)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.error = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                guard response.status else {
                    self.error = response.message.isEmpty
                        ? "Couldn't save attendance. Try again."
                        : response.message
                    return
                }
                if self.date == day {
                    // Fold the saved picks into the rows so the screen is right before the reload lands.
                    self.staff = self.staff.map { row in
                        guard let type = marks[row.userID] else { return row }
                        var updated = row
                        updated.attendanceType = type.rawValue
                        return updated
                    }
                    // Only what went out: a row re-picked while saving stays unsaved.
                    self.draft = self.draft.filter { marks[$0.key] != $0.value }
                    if self.filter == .edited { self.filter = .all }
                }
                self.message = response.message.isEmpty
                    ? "Attendance saved for \(marks.count) staff"
                    : response.message
                ManualAttendanceBus.shared.attendanceChanged()
                if self.date == day { self.load() }
            }
            .store(in: &cancellables)
    }
}

/// A day corrected on the mark screen shows up on the history screen on the way back.
/// Mirrors Android `CashCollectionBus.Change.Attendance`.
final class ManualAttendanceBus {
    static let shared = ManualAttendanceBus()
    private init() {}

    let changes = PassthroughSubject<Void, Never>()

    func attendanceChanged() { changes.send(()) }
}

extension String {
    /// Nil for a blank server string, so a `??` default can take over.
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
