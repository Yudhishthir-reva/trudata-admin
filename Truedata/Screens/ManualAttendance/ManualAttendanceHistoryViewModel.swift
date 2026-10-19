//
//  ManualAttendanceHistoryViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

/// One person on the day: from the staff list (photo, designation, unmarked people) and the
/// history (who marked). Mirrors Android `HistoryRow`.
struct ManualAttendanceHistoryRow: Identifiable, Equatable {
    let userID: Int
    let name: String
    let designation: String?
    let image: String?
    let type: ManualAttendanceType?
    let markedBy: Int?

    var id: Int { userID }
}

/// Nil `type` with `unmarkedOnly` false shows everyone.
struct ManualAttendanceHistoryFilter: Equatable {
    var type: ManualAttendanceType?
    var unmarkedOnly = false
}

/// One day's attendance for everyone: `manual-attendance/staff-list` gives every person and what
/// they are marked (unmarked included), `manual-attendance/history` adds who marked it. Either
/// alone is still shown; only both failing is an error.
/// Mirrors Android `AttendanceHistoryViewModel`.
final class ManualAttendanceHistoryViewModel: ObservableObject {

    @Published private(set) var date = ManualAttendanceDate.today
    @Published private(set) var isLoading = true
    @Published private(set) var error: String?
    @Published private(set) var weeklyOff: String?
    @Published private(set) var rows: [ManualAttendanceHistoryRow] = []
    @Published var filter = ManualAttendanceHistoryFilter()
    @Published var query = ""
    /// User id → name, for "marked by"; empty when the staff list couldn't load.
    @Published private(set) var names: [Int: String] = [:]
    /// The person opened in the detail sheet.
    @Published var open: ManualAttendanceHistoryRow?

    private let service = ManualAttendanceServiceManager()
    private var loadCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadNames()
        // A day corrected on the mark screen shows up here on the way back.
        ManualAttendanceBus.shared.changes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    // MARK: - Derived state

    var counts: [ManualAttendanceType: Int] {
        rows.compactMap(\.type).reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    var markedCount: Int { rows.filter { $0.type != nil }.count }

    var unmarkedCount: Int { rows.count - markedCount }

    var visible: [ManualAttendanceHistoryRow] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return rows.filter { row in
            let matches = search.isEmpty
                || row.name.localizedCaseInsensitiveContains(search)
                || (row.designation ?? "").localizedCaseInsensitiveContains(search)
            guard matches else { return false }
            if filter.unmarkedOnly { return row.type == nil }
            if let type = filter.type { return row.type == type }
            return true
        }
    }

    /// ``visible`` grouped in status order, unmarked last, for the sectioned list.
    var groups: [(type: ManualAttendanceType?, rows: [ManualAttendanceHistoryRow])] {
        let byType = Dictionary(grouping: visible, by: \.type)
        let order: [ManualAttendanceType?] = ManualAttendanceType.allCases.map { $0 } + [nil]
        return order.compactMap { type in
            guard let rows = byType[type], !rows.isEmpty else { return nil }
            return (type, rows)
        }
    }

    var isWeeklyOff: Bool {
        weeklyOff != nil || (rows.isEmpty && ManualAttendanceDate.isWeeklyOff(date))
    }

    func markedByName(_ row: ManualAttendanceHistoryRow) -> String? {
        row.markedBy.flatMap { names[$0] }
    }

    // MARK: - Intents

    func changeDate(to newDate: Date) {
        let day = ManualAttendanceDate.startOfDay(newDate)
        guard day != date else { return }
        date = day
        rows = []
        weeklyOff = nil
        open = nil
        load()
    }

    // MARK: - Network

    func load() {
        loadCancellable?.cancel()
        let day = date
        isLoading = true
        error = nil

        let staff = service.fetchStaffList(date: ManualAttendanceDate.day(day))
            .map { Optional($0) }
            .replaceError(with: nil)
        let history = service.fetchHistory(date: ManualAttendanceDate.day(day))
            .map { Optional($0) }
            .replaceError(with: nil)

        loadCancellable = Publishers.Zip(staff, history)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLoading = false
            } receiveValue: { [weak self] staffResponse, historyResponse in
                guard let self, self.date == day else { return }
                self.isLoading = false

                let staffData = (staffResponse?.status == true) ? staffResponse?.data : nil
                let records = (historyResponse?.status == true) ? (historyResponse?.records ?? []) : []

                guard staffData != nil || historyResponse?.status == true else {
                    self.error = [staffResponse?.message, historyResponse?.message]
                        .compactMap { $0?.nilIfBlank }.first
                        ?? "Couldn't load attendance for this day."
                    return
                }
                self.error = nil

                let byUser = Dictionary(records.map { ($0.userID, $0) }, uniquingKeysWith: { first, _ in first })
                let rows: [ManualAttendanceHistoryRow]
                if let staffData {
                    rows = staffData.staff.filter { $0.userID > 0 }.map { member in
                        let record = byUser[member.userID]
                        return ManualAttendanceHistoryRow(
                            userID: member.userID,
                            name: member.name,
                            designation: member.designation,
                            image: member.profileImage,
                            type: ManualAttendanceType(code: member.attendanceType ?? record?.attendanceType),
                            markedBy: record?.markedBy
                        )
                    }
                } else {
                    rows = records.map { record in
                        ManualAttendanceHistoryRow(
                            userID: record.userID,
                            name: record.name,
                            designation: nil,
                            image: nil,
                            type: ManualAttendanceType(code: record.attendanceType),
                            markedBy: record.markedBy
                        )
                    }
                }

                self.weeklyOff = staffData?.isWeeklyOff == true
                    ? (staffData?.weeklyOffMessage?.nilIfBlank
                       ?? "This is a weekly off. Attendance isn't marked for it.")
                    : nil
                self.rows = rows.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.open = self.open.flatMap { opened in rows.first { $0.userID == opened.userID } }
            }
    }

    /// "Marked by" names; the manual-attendance endpoints only send the marker's user id.
    private func loadNames() {
        HomePrefetchServiceManager().fetchStaffList()
            .receive(on: RunLoop.main)
            // A failed staff list just means no names to show against "marked by".
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, response.status else { return }
                self.names = Dictionary(
                    response.data.filter { $0.id > 0 }.map { ($0.id, $0.name) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            .store(in: &cancellables)
    }
}
