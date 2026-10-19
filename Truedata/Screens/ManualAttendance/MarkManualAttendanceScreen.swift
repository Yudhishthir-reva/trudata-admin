//
//  MarkManualAttendanceScreen.swift
//  Truedata
//

import SwiftUI
import Combine

/// Mirrors Android `MarkAttendanceScreen`: numbered steps down the screen, a first-time guide,
/// status picks as radio options, a quick-mark shortcut set apart from them, and a Yes / No check
/// before anything is saved. Future days can be opened and marked.
struct MarkManualAttendanceScreen: View {
    var onHome: () -> Void

    @StateObject private var viewModel: MarkManualAttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("manual_attendance_mark_guide_v1") private var tipSeen = false

    @State private var confirmSave = false
    @State private var quickConfirm: ManualAttendanceType?
    /// Anything that would drop unsaved picks asks first: leaving, going home, or changing the day.
    @State private var pendingLeave: PendingLeave?
    @State private var banner: String?

    init(date: Date? = nil, onHome: @escaping () -> Void) {
        self.onHome = onHome
        _viewModel = StateObject(wrappedValue: MarkManualAttendanceViewModel(date: date ?? ManualAttendanceDate.today))
    }

    private enum PendingLeave: Identifiable {
        case back, home, refresh, day(Date)
        var id: String {
            switch self {
            case .back: return "back"
            case .home: return "home"
            case .refresh: return "refresh"
            case .day(let date): return "day-\(ManualAttendanceDate.day(date))"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !tipSeen {
                        ManualAttendanceGuideCard(
                            title: "How to mark attendance",
                            steps: [
                                ("Choose the day", "Use the arrows or tap the date. Upcoming days work too, e.g. for a planned holiday."),
                                ("Quick mark everyone (optional)", "One tap gives everyone the same status. Then fix only the few who differ."),
                                ("Pick a status for each person", "Tap one option. The filled circle with a tick is what's chosen; grey options are not."),
                                ("Save", "Nothing is stored until you tap Save attendance and confirm with Yes."),
                            ],
                            onDismiss: { tipSeen = true }
                        )
                    }
                    ManualAttendanceStepHeader(number: 1, title: "Choose the day") {
                        if tipSeen { ManualAttendanceHelpButton { tipSeen = false } }
                    }
                    ManualAttendanceDayBar(date: viewModel.date) { guarded(.day($0)) }
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
            if viewModel.canMark { bottomBar }
        }
        .overlay(alignment: .bottom) { bannerView }
        .overlay { dialogs }
        .onAppear { if viewModel.staff.isEmpty { viewModel.load() } }
        .onReceive(viewModel.$message.compactMap { $0 }) { text in
            banner = text
            viewModel.message = nil
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 12) {
            Button { guarded(.back) } label: { Image(systemName: "arrow.left") }
                .accessibilityLabel("Back")
            Text("Mark Attendance").font(.title3.weight(.semibold))
            Spacer()
            Button { guarded(.refresh) } label: { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel("Refresh")
            Button { guarded(.home) } label: { Image(systemName: "house.fill") }
                .accessibilityLabel("Home")
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(CashStyle.gradient, in: UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
        .background(CashStyle.gradient.ignoresSafeArea(edges: .top))
    }

    private var bottomBar: some View {
        ManualAttendanceBottomBar {
            if viewModel.hasChanges {
                ManualAttendanceBarSummary(
                    label: "Ready to save · nothing is saved until you tap Save",
                    value: "\(viewModel.draft.count) change\(viewModel.draft.count == 1 ? "" : "s")",
                    status: "Not saved",
                    tone: ManualAttendanceStyle.warn
                )
            } else {
                let allMarked = viewModel.unmarkedCount == 0
                ManualAttendanceBarSummary(
                    label: "Marked for \(ManualAttendanceDate.relativeLabel(viewModel.date).lowercased())",
                    value: "\(viewModel.markedCount) of \(viewModel.staff.count)",
                    status: allMarked ? "All marked" : "\(viewModel.unmarkedCount) left",
                    tone: allMarked ? ManualAttendanceType.present.tint : ManualAttendanceStyle.textMuted
                )
            }
        } content: {
            if viewModel.hasChanges {
                ManualAttendanceIconButton(
                    icon: "arrow.uturn.backward",
                    label: "Undo all changes",
                    color: ManualAttendanceStyle.textMuted
                ) { viewModel.discardChanges() }
            }

            Button { confirmSave = true } label: {
                HStack(spacing: 7) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill").font(.system(size: 15, weight: .bold))
                    }
                    Text(viewModel.hasChanges ? "Save attendance" : "All saved")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    viewModel.hasChanges ? AnyShapeStyle(CashStyle.gradient) : AnyShapeStyle(ManualAttendanceStyle.unmarked),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
        }
    }

    // MARK: - Sections

    @ViewBuilder private var content: some View {
        if viewModel.isLoading && viewModel.staff.isEmpty && viewModel.weeklyOff == nil {
            ManualAttendanceLoadingBlock()
        } else if let loadError = viewModel.loadError, viewModel.staff.isEmpty {
            ManualAttendanceErrorBlock(message: loadError) { viewModel.load() }
        } else if let weeklyOff = viewModel.weeklyOff {
            ManualAttendanceEmptyBlock(icon: "bed.double.fill", title: "Weekly off", message: weeklyOff)
        } else if viewModel.staff.isEmpty {
            ManualAttendanceEmptyBlock(
                icon: "person.3.fill",
                title: "No staff to mark",
                message: "There's no one else on the staff list yet."
            )
        } else {
            hero
            ManualAttendanceStepHeader(number: 2, title: "Quick mark everyone", subtitle: "Optional shortcut")
            quickMarkCard
            ManualAttendanceStepHeader(
                number: 3,
                title: "Mark each person",
                subtitle: "Tap one option per person · \(viewModel.staff.count) staff"
            )
            searchAndFilter
            staffRows
            ManualAttendanceStepHeader(number: 4, title: "Save", subtitle: "Tap Save attendance below and confirm with Yes")
        }
    }

    /// How far the day is: marked out of everyone, split by status, with a colour key.
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
                Text(" of \(viewModel.staff.count) marked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            ManualAttendanceSplitBar(counts: viewModel.counts, total: viewModel.staff.count)
            ManualAttendanceLegend(counts: viewModel.counts, unmarked: viewModel.unmarkedCount)
                .padding(.top, 2)
        }
    }

    /// The shortcut, set apart from the per-person picks: brand-tinted card with solid action
    /// buttons (not radio options) that ask before applying.
    private var quickMarkCard: some View {
        let rows = viewModel.visible
        let narrowed = rows.count != viewModel.staff.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.cerulean, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(narrowed ? "Mark these \(rows.count) at once" : "Mark all \(rows.count) at once")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppTheme.darkMidnightBlue)
                    Text(narrowed
                         ? "Applies only to the staff matching your search or filter"
                         : "Sets everyone to one status. You can still change anyone afterwards.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ManualAttendanceStyle.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                quickButton(.present, enabled: !rows.isEmpty)
                quickButton(.absent, enabled: !rows.isEmpty)
            }
            HStack(spacing: 8) {
                quickButton(.firstHalf, enabled: !rows.isEmpty)
                quickButton(.secondHalf, enabled: !rows.isEmpty)
                quickButton(.holiday, enabled: !rows.isEmpty)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [ManualAttendanceStyle.container, .white], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cerulean.opacity(viewModel.markedCount == 0 && !viewModel.hasChanges ? 0.9 : 0.35), lineWidth: 2)
        )
    }

    /// A solid action in the status colour — deliberately unlike the grey radio options below.
    private func quickButton(_ type: ManualAttendanceType, enabled: Bool) -> some View {
        Button { quickConfirm = type } label: {
            HStack(spacing: 5) {
                Image(systemName: type.icon).font(.system(size: 13, weight: .semibold))
                Text("All \(type.shortLabel)")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(type.tint.opacity(enabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Mark everyone \(type.shortLabel)")
    }

    private var searchAndFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            ManualAttendanceSearchField(text: $viewModel.query)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ManualAttendanceChip(
                        label: "All", count: viewModel.staff.count,
                        isSelected: viewModel.filter == .all
                    ) { viewModel.filter = .all }
                    ManualAttendanceChip(
                        label: "Not marked", count: viewModel.unmarkedCount,
                        tint: ManualAttendanceStyle.unmarked, icon: "circle",
                        isSelected: viewModel.filter == .unmarked
                    ) { viewModel.filter = .unmarked }
                    if viewModel.hasChanges || viewModel.filter == .edited {
                        ManualAttendanceChip(
                            label: "Changed", count: viewModel.draft.count,
                            tint: ManualAttendanceStyle.warn, icon: "pencil",
                            isSelected: viewModel.filter == .edited
                        ) { viewModel.filter = .edited }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder private var staffRows: some View {
        let rows = viewModel.visible
        if rows.isEmpty {
            ManualAttendanceEmptyBlock(
                icon: "magnifyingglass",
                title: {
                    switch viewModel.filter {
                    case .unmarked: return "Everyone is marked"
                    case .edited: return "No unsaved changes"
                    case .all: return "No one matches"
                    }
                }(),
                message: viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Switch the filter to see the rest."
                    : "Nobody named \"\(viewModel.query.trimmingCharacters(in: .whitespaces))\" here."
            )
        } else {
            ForEach(rows) { member in
                staffCard(member)
            }
        }
    }

    /// One person: who they are, what is chosen in words (and what it was before an unsaved
    /// change), and the radio options. The accent strip and border take the chosen status colour.
    private func staffCard(_ member: ManualAttendanceStaff) -> some View {
        let current = viewModel.current(member)
        let saved = viewModel.saved(member.userID)
        let edited = viewModel.draft[member.userID] != nil
        let accent = current?.tint ?? Color(hex: "E5E7EB")
        let border: Color = edited ? ManualAttendanceStyle.warn
            : (current?.tint.opacity(0.35) ?? ManualAttendanceStyle.border)

        return HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ManualAttendanceAvatar(name: member.name, imageURL: member.profileImage, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.name.isEmptyString ? "Staff #\(member.userID)" : member.name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(ManualAttendanceStyle.text)
                            .lineLimit(1)
                        Text(member.designation?.nilIfBlank ?? "—")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManualAttendanceStyle.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    ManualAttendanceStatusBadge(type: current)
                }
                ManualAttendanceRadioGroup(selected: current) { viewModel.mark(userID: member.userID, as: $0) }
                if edited {
                    HStack(spacing: 6) {
                        Text("Changed from \(saved?.shortLabel ?? "Not marked") · not saved yet")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(ManualAttendanceStyle.warn)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { viewModel.revert(userID: member.userID) } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ManualAttendanceStyle.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                } else if current == nil {
                    Text("Not marked yet — tap one option above")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ManualAttendanceStyle.textFaint)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
        }
        .background(ManualAttendanceStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: edited ? 1.5 : 1))
        .animation(.easeInOut(duration: 0.2), value: current)
    }

    // MARK: - Dialogs & banner

    @ViewBuilder private var dialogs: some View {
        if let leave = pendingLeave {
            ManualAttendanceConfirm(
                title: "Discard changes?",
                message: "\(viewModel.draft.count) unsaved change\(viewModel.draft.count == 1 ? "" : "s") for \(ManualAttendanceDate.longLabel(viewModel.date)) will be lost.",
                confirmTitle: "Discard",
                confirmColor: AppTheme.errorRed,
                icon: "exclamationmark.triangle.fill",
                onConfirm: {
                    pendingLeave = nil
                    viewModel.discardChanges()
                    perform(leave)
                },
                onDismiss: { pendingLeave = nil }
            )
        } else if let type = quickConfirm {
            let rows = viewModel.visible
            let narrowed = rows.count != viewModel.staff.count
            ManualAttendanceConfirm(
                title: "Mark \(rows.count) as \(type.shortLabel)?",
                message: "Everyone \(narrowed ? "shown" : "on the list") will be set to \(type.label) for \(ManualAttendanceDate.longLabel(viewModel.date)). It isn't saved until you tap Save attendance.",
                confirmTitle: "Yes, mark all",
                confirmColor: type.tint,
                icon: type.icon,
                onConfirm: {
                    quickConfirm = nil
                    viewModel.markAll(rows.map(\.userID), as: type)
                },
                onDismiss: { quickConfirm = nil }
            )
        } else if confirmSave {
            ManualAttendanceSaveConfirm(
                date: viewModel.date,
                changes: viewModel.changeCounts,
                onYes: { confirmSave = false; viewModel.save() },
                onNo: { confirmSave = false }
            )
        }
    }

    @ViewBuilder private var bannerView: some View {
        if let banner {
            Text(banner)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.darkMidnightBlue, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: banner) {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    withAnimation { self.banner = nil }
                }
        }
    }

    // MARK: - Guarded navigation

    private func guarded(_ leave: PendingLeave) {
        if viewModel.hasChanges {
            pendingLeave = leave
        } else {
            perform(leave)
        }
    }

    private func perform(_ leave: PendingLeave) {
        switch leave {
        case .back: dismiss()
        case .home: onHome()
        case .refresh: viewModel.load()
        case .day(let date): viewModel.changeDate(to: date)
        }
    }
}
