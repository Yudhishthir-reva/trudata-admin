//
//  ManualAttendanceHistoryScreen.swift
//  Truedata
//

import SwiftUI

/// Mirrors Android `AttendanceHistoryScreen`: every staff member for the day, marked or not,
/// grouped by status with colour-coded headers, a split bar and colour key in the hero, status
/// filter chips with counts, and a detail sheet per person.
struct ManualAttendanceHistoryScreen: View {
    var onHome: () -> Void

    @StateObject private var viewModel = ManualAttendanceHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("manual_attendance_history_guide_v1") private var tipSeen = false
    @State private var editingDay: ManualAttendanceEditDay?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !tipSeen {
                        ManualAttendanceGuideCard(
                            title: "Reading attendance history",
                            steps: [
                                ("Pick a day", "Use the arrows or tap the date. Upcoming days show anything marked ahead."),
                                ("Read the colours", "Each person is grouped by status. Grey means no one has marked them yet."),
                                ("Tap a person", "See their status, who marked it, and change it if needed."),
                            ],
                            onDismiss: { tipSeen = true }
                        )
                    }
                    HStack(alignment: .top, spacing: 4) {
                        ManualAttendanceDayBar(date: viewModel.date) { viewModel.changeDate(to: $0) }
                        if tipSeen { ManualAttendanceHelpButton { tipSeen = false } }
                    }
                    content
                }
                .padding(12)
            }
        }
        .background(ManualAttendanceStyle.page)
        .tint(CashStyle.green)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.isWeeklyOff && !viewModel.isLoading && viewModel.error == nil {
                ManualAttendanceBottomBar {
                    Button { editingDay = ManualAttendanceEditDay(date: viewModel.date) } label: {
                        Label(
                            viewModel.markedCount == 0 ? "Mark this day" : "Change this day's attendance",
                            systemImage: "calendar.badge.plus"
                        )
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(item: $editingDay) { day in
            MarkManualAttendanceScreen(date: day.date, onHome: onHome)
        }
        .sheet(item: $viewModel.open) { row in
            detailSheet(row)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { if viewModel.rows.isEmpty { viewModel.load() } }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: { Image(systemName: "arrow.left") }
                .accessibilityLabel("Back")
            Text("Attendance History").font(.title3.weight(.semibold))
            Spacer()
            Button { viewModel.load() } label: { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel("Refresh")
            Button(action: onHome) { Image(systemName: "house.fill") }
                .accessibilityLabel("Home")
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(CashStyle.gradient, in: UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
        .background(CashStyle.gradient.ignoresSafeArea(edges: .top))
    }

    // MARK: - Sections

    @ViewBuilder private var content: some View {
        if viewModel.isLoading && viewModel.rows.isEmpty {
            ManualAttendanceLoadingBlock()
        } else if let error = viewModel.error, viewModel.rows.isEmpty {
            ManualAttendanceErrorBlock(message: error) { viewModel.load() }
        } else if viewModel.isWeeklyOff {
            ManualAttendanceEmptyBlock(
                icon: "bed.double.fill",
                title: "Weekly off",
                message: viewModel.weeklyOff ?? "Sunday is a weekly off, so no attendance is marked for it."
            )
        } else if viewModel.rows.isEmpty {
            ManualAttendanceEmptyBlock(
                icon: "calendar.badge.exclamationmark",
                title: "Nothing marked",
                message: "No one's attendance was marked for \(ManualAttendanceDate.longLabel(viewModel.date))."
            )
        } else {
            hero
            filters
            groupedRows
        }
    }

    private var hero: some View {
        ManualAttendanceHero {
            Text("\(ManualAttendanceDate.relativeLabel(viewModel.date).uppercased()) · \(ManualAttendanceDate.longLabel(viewModel.date).uppercased())")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.75))
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("\(viewModel.markedCount)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                Text(" of \(viewModel.rows.count) staff marked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            ManualAttendanceSplitBar(counts: viewModel.counts, total: viewModel.rows.count)
            ManualAttendanceLegend(counts: viewModel.counts, unmarked: viewModel.unmarkedCount)
                .padding(.top, 2)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ManualAttendanceSearchField(text: $viewModel.query)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ManualAttendanceChip(
                        label: "All", count: viewModel.rows.count,
                        isSelected: viewModel.filter == ManualAttendanceHistoryFilter()
                    ) { viewModel.filter = ManualAttendanceHistoryFilter() }

                    ForEach(ManualAttendanceType.allCases) { type in
                        ManualAttendanceChip(
                            label: type.shortLabel, count: viewModel.counts[type] ?? 0,
                            tint: type.tint, icon: type.icon,
                            isSelected: viewModel.filter.type == type
                        ) { viewModel.filter = ManualAttendanceHistoryFilter(type: type) }
                    }

                    ManualAttendanceChip(
                        label: "Not marked", count: viewModel.unmarkedCount,
                        tint: ManualAttendanceStyle.unmarked, icon: "circle",
                        isSelected: viewModel.filter.unmarkedOnly
                    ) { viewModel.filter = ManualAttendanceHistoryFilter(unmarkedOnly: true) }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder private var groupedRows: some View {
        let groups = viewModel.groups
        if groups.isEmpty {
            ManualAttendanceEmptyBlock(
                icon: "magnifyingglass",
                title: "No one matches",
                message: viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "No one has this status on this day."
                    : "Nobody named \"\(viewModel.query.trimmingCharacters(in: .whitespaces))\" for this filter."
            )
        } else {
            ForEach(groups, id: \.type) { group in
                groupHeader(group.type, count: group.rows.count)
                ForEach(group.rows) { row in
                    personRow(row)
                }
            }
        }
    }

    private func groupHeader(_ type: ManualAttendanceType?, count: Int) -> some View {
        let tint = type?.tint ?? ManualAttendanceStyle.unmarked
        return HStack(spacing: 7) {
            Image(systemName: type?.icon ?? "circle")
                .font(.system(size: 14))
                .foregroundStyle(tint)
            Text(type?.label ?? "Not marked yet")
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(ManualAttendanceStyle.text)
            Text("\(count)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private func personRow(_ row: ManualAttendanceHistoryRow) -> some View {
        let tint = row.type?.tint ?? ManualAttendanceStyle.unmarked
        let subtitle = [row.designation?.nilIfBlank, viewModel.markedByName(row).map { "by \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")

        return Button { viewModel.open = row } label: {
            HStack(spacing: 0) {
                Rectangle().fill(tint).frame(width: 5)
                HStack(spacing: 10) {
                    ManualAttendanceAvatar(name: row.name, imageURL: row.image, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name.isEmptyString ? "Staff #\(row.userID)" : row.name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(ManualAttendanceStyle.text)
                            .lineLimit(1)
                        Text(subtitle.isEmpty ? "—" : subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManualAttendanceStyle.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    ManualAttendanceStatusBadge(type: row.type)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ManualAttendanceStyle.textFaint)
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.vertical, 11)
            }
            .background(ManualAttendanceStyle.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(row.type != nil ? tint.opacity(0.3) : ManualAttendanceStyle.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(row.name)")
    }

    /// One person on the day: big status card, what it means, who marked it, and a way to change it.
    private func detailSheet(_ row: ManualAttendanceHistoryRow) -> some View {
        let tint = row.type?.tint ?? ManualAttendanceStyle.unmarked
        return ScrollView {
            VStack(spacing: 12) {
                ManualAttendanceAvatar(name: row.name, imageURL: row.image, size: 72)
                VStack(spacing: 2) {
                    Text(row.name.isEmptyString ? "Staff #\(row.userID)" : row.name)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(ManualAttendanceStyle.text)
                    if let designation = row.designation?.nilIfBlank {
                        Text(designation)
                            .font(.system(size: 13))
                            .foregroundStyle(ManualAttendanceStyle.textMuted)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: row.type?.icon ?? "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.type?.label ?? "Not marked yet")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(row.type != nil ? tint : ManualAttendanceStyle.text)
                        Text(row.type?.meaning ?? "No one has marked this person for the day.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(ManualAttendanceStyle.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.5), lineWidth: 1.5))

                VStack(spacing: 0) {
                    detailLine("calendar", "Date", "\(ManualAttendanceDate.longLabel(viewModel.date)) · \(ManualAttendanceDate.relativeLabel(viewModel.date))")
                    if row.type != nil {
                        detailLine("person.badge.shield.checkmark", "Marked by", viewModel.markedByName(row) ?? "—")
                    }
                }
                .padding(.horizontal, 14)
                .background(ManualAttendanceStyle.page, in: RoundedRectangle(cornerRadius: 14))

                if !viewModel.isWeeklyOff {
                    Button {
                        viewModel.open = nil
                        editingDay = ManualAttendanceEditDay(date: viewModel.date)
                    } label: {
                        Label(
                            row.type == nil ? "Mark attendance for this day" : "Change attendance",
                            systemImage: "calendar.badge.plus"
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color.white)
    }

    private func detailLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ManualAttendanceStyle.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}

/// `navigationDestination(item:)` needs an Identifiable; a bare `Date` must not be made one here.
struct ManualAttendanceEditDay: Identifiable, Hashable {
    let date: Date
    var id: String { ManualAttendanceDate.day(date) }
}
