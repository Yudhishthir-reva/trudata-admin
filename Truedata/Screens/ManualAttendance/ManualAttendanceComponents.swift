//
//  ManualAttendanceComponents.swift
//  Truedata
//

import SwiftUI

// MARK: - Day bar

/// ‹ Tue, 13 Oct 2026 › — steps a day at a time; tapping the date opens a calendar. Any day can be
/// opened, future ones included (to mark a planned holiday or leave ahead). Mirrors Android `DayBar`.
struct ManualAttendanceDayBar: View {
    let date: Date
    /// History may look ahead too; only a screen that must not accept future days passes false.
    var allowsFuture = true
    let onChange: (Date) -> Void
    @State private var picking = false

    private var today: Date { ManualAttendanceDate.today }
    private var canGoForward: Bool { allowsFuture || date < today }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                stepButton("chevron.left", label: "Previous day", enabled: true) {
                    onChange(ManualAttendanceDate.adding(days: -1, to: date))
                }

                Button { picking = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.cerulean)
                        VStack(spacing: 1) {
                            Text(ManualAttendanceDate.longLabel(date))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ManualAttendanceStyle.text)
                            Text(subtitle.text)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(subtitle.color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose a date")

                stepButton("chevron.right", label: "Next day", enabled: canGoForward) {
                    onChange(ManualAttendanceDate.adding(days: 1, to: date))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(ManualAttendanceStyle.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ManualAttendanceStyle.border, lineWidth: 1))

            if date != today {
                Button("Jump to today") { onChange(today) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.cerulean)
                    .padding(.top, 6)
            }
        }
        .sheet(isPresented: $picking) {
            ManualAttendanceDatePicker(date: date) { picked in
                picking = false
                onChange(ManualAttendanceDate.startOfDay(picked))
            }
        }
    }

    private var subtitle: (text: String, color: Color) {
        if ManualAttendanceDate.isWeeklyOff(date) {
            return ("Weekly off", ManualAttendanceStyle.warn)
        }
        if date > today {
            return ("\(ManualAttendanceDate.relativeLabel(date)) · upcoming", ManualAttendanceStyle.info)
        }
        return (ManualAttendanceDate.relativeLabel(date), ManualAttendanceStyle.textMuted)
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.cerulean : ManualAttendanceStyle.textFaint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct ManualAttendanceDatePicker: View {
    let date: Date
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection = Date()

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppTheme.cerulean)
                .padding(.horizontal, 12)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { onPick(selection) }.fontWeight(.bold)
                    }
                }
                .navigationTitle("Choose a date")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { selection = date }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Status picker

/// Five radio options, one chosen at most. Only the chosen one carries colour; the rest stay
/// neutral grey with an empty circle, so what is selected is never in doubt.
/// Mirrors Android `AttendanceRadioGroup`.
struct ManualAttendanceRadioGroup: View {
    let selected: ManualAttendanceType?
    let onSelect: (ManualAttendanceType) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(ManualAttendanceType.allCases) { type in
                radio(type)
            }
        }
    }

    private func radio(_ type: ManualAttendanceType) -> some View {
        let isSelected = selected == type
        return Button { onSelect(type) } label: {
            VStack(spacing: 4) {
                ManualAttendanceRadioDot(isSelected: isSelected, tint: type.tint)
                Text(type.shortLabel)
                    .font(.system(size: 10.5, weight: isSelected ? .heavy : .medium))
                    .foregroundStyle(isSelected ? type.tint : ManualAttendanceStyle.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 7)
            .background(
                isSelected ? type.tint.opacity(0.12) : Color(hex: "F9FAFB"),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.tint : Color(hex: "E5E7EB"), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// An empty ring, or a filled disc whose check springs in.
private struct ManualAttendanceRadioDot: View {
    let isSelected: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? tint : Color(hex: "C4C9D0"), lineWidth: 2)
            if isSelected {
                Circle().fill(tint)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
    }
}

// MARK: - Status read-outs

/// What is marked, in words and colour; grey "Not marked" when nothing is.
struct ManualAttendanceStatusBadge: View {
    let type: ManualAttendanceType?

    var body: some View {
        let tint = type?.tint ?? ManualAttendanceStyle.unmarked
        HStack(spacing: 4) {
            Image(systemName: type?.icon ?? "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(type?.shortLabel ?? "Not marked")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(type == nil ? ManualAttendanceStyle.textMuted : tint)
                .lineLimit(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(tint.opacity(0.13), in: Capsule())
    }
}

/// One bar split by status, in proportion, with grey for whoever is not marked.
struct ManualAttendanceSplitBar: View {
    let counts: [ManualAttendanceType: Int]
    let total: Int
    var onDark = true

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if total > 0 {
                    ForEach(ManualAttendanceType.allCases) { type in
                        let share = Double(counts[type] ?? 0) / Double(total)
                        if share > 0 {
                            Rectangle()
                                .fill(type.tint)
                                .frame(width: geometry.size.width * share)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
        .background(onDark ? Color.white.opacity(0.2) : ManualAttendanceStyle.track)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .animation(.easeInOut(duration: 0.4), value: total)
    }
}

/// A colour key: dot, label and count per status, in rows of three.
struct ManualAttendanceLegend: View {
    let counts: [ManualAttendanceType: Int]
    let unmarked: Int
    var onDark = true

    private struct Item: Identifiable {
        let id: Int
        let tint: Color
        let label: String
        let count: Int
    }

    private var rows: [[Item]] {
        let items = ManualAttendanceType.allCases.enumerated().map { index, type in
            Item(id: index, tint: type.tint, label: type.shortLabel, count: counts[type] ?? 0)
        } + [Item(
            id: ManualAttendanceType.allCases.count,
            tint: ManualAttendanceStyle.unmarked,
            label: "Not marked",
            count: unmarked
        )]
        return stride(from: 0, to: items.count, by: 3).map { start in
            Array(items[start..<min(start + 3, items.count)])
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { item in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(onDark && item.tint == ManualAttendanceStyle.unmarked
                                      ? Color.white.opacity(0.5) : item.tint)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white.opacity(onDark ? 0.7 : 0), lineWidth: 1))
                            Text(item.label)
                                .font(.system(size: 10.5))
                                .foregroundStyle(onDark ? Color.white.opacity(0.85) : ManualAttendanceStyle.textMuted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(onDark ? Color.white : ManualAttendanceStyle.text)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            onDark ? Color.white.opacity(0.12) : ManualAttendanceStyle.track,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    // Keeps the last, short row's cells the same width as the rows above it.
                    ForEach(row.count..<3, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}

/// The brand-gradient card that carries the one figure a screen is about. Mirrors Android `CcHero`.
struct ManualAttendanceHero<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Guide

/// A tip card for first-time users; dismissed per device. Mirrors Android `GuideCard`.
struct ManualAttendanceGuideCard: View {
    let title: String
    let steps: [(String, String)]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ManualAttendanceStyle.info)
                    .frame(width: 30, height: 30)
                    .background(ManualAttendanceStyle.info.opacity(0.15), in: Circle())
                Text(title)
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(ManualAttendanceStyle.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ManualAttendanceStyle.textMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide tips")
            }

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(ManualAttendanceStyle.info, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManualAttendanceStyle.text)
                        Text(step.1)
                            .font(.system(size: 12))
                            .foregroundStyle(ManualAttendanceStyle.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ManualAttendanceStatusKey()

            Button("Got it", action: onDismiss)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ManualAttendanceStyle.info)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(ManualAttendanceStyle.infoBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ManualAttendanceStyle.info.opacity(0.25), lineWidth: 1)
        )
    }
}

/// The colour key inside a guide: every status with its colour and what it means.
struct ManualAttendanceStatusKey: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ManualAttendanceType.allCases) { type in
                HStack(spacing: 8) {
                    Image(systemName: type.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(type.tint)
                        .frame(width: 18)
                    Text(type.shortLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(type.tint)
                        .frame(width: 64, alignment: .leading)
                    Text(type.meaning)
                        .font(.system(size: 12))
                        .foregroundStyle(ManualAttendanceStyle.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A numbered step title, so a first-time user can follow the screen top to bottom.
struct ManualAttendanceStepHeader<Trailing: View>: View {
    let number: Int
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppTheme.cerulean, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(ManualAttendanceStyle.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ManualAttendanceStyle.textMuted)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.top, 4)
    }
}

extension ManualAttendanceStepHeader where Trailing == EmptyView {
    init(number: Int, title: String, subtitle: String? = nil) {
        self.init(number: number, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// A small round "?" that reopens a dismissed guide. Mirrors Android `HelpButton`.
struct ManualAttendanceHelpButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ManualAttendanceStyle.info)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How this works")
    }
}

// MARK: - Dialogs

/// A dimmed modal with a card, for the confirmations that need more than an alert's two lines.
struct ManualAttendanceDialog<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 10, content: content)
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

/// The Yes / No check before attendance is saved: the day, how many people, and the count per
/// status, so a mis-tap on "mark everyone" is caught here rather than in the records.
struct ManualAttendanceSaveConfirm: View {
    let date: Date
    let changes: [ManualAttendanceType: Int]
    let onYes: () -> Void
    let onNo: () -> Void

    private var total: Int { changes.values.reduce(0, +) }

    var body: some View {
        ManualAttendanceDialog(onDismiss: onNo) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.cerulean)
                .frame(width: 60, height: 60)
                .background(AppTheme.cerulean.opacity(0.12), in: Circle())

            Text("Save attendance?")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(ManualAttendanceStyle.text)

            Text("\(total) staff for \(ManualAttendanceDate.longLabel(date))"
                 + (date > ManualAttendanceDate.today ? " (upcoming)" : ""))
                .font(.system(size: 13.5))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(ManualAttendanceType.allCases.filter { (changes[$0] ?? 0) > 0 }) { type in
                    HStack(spacing: 8) {
                        Image(systemName: type.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(type.tint)
                        Text(type.label)
                            .font(.system(size: 13))
                            .foregroundStyle(ManualAttendanceStyle.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(changes[type] ?? 0)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(type.tint)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(ManualAttendanceStyle.page, in: RoundedRectangle(cornerRadius: 14))

            Text("You can open this day again later to change it.")
                .font(.system(size: 11.5))
                .foregroundStyle(ManualAttendanceStyle.textFaint)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("No", action: onNo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ManualAttendanceStyle.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(ManualAttendanceStyle.page, in: RoundedRectangle(cornerRadius: 12))

                Button(action: onYes) {
                    Label("Yes, save", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Title / body / one coloured action, for "discard changes" and "mark everyone".
struct ManualAttendanceConfirm: View {
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color = AppTheme.cerulean
    var icon: String?
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ManualAttendanceDialog(onDismiss: onDismiss) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(confirmColor)
                    .frame(width: 56, height: 56)
                    .background(confirmColor.opacity(0.12), in: Circle())
            }
            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(ManualAttendanceStyle.text)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Cancel", action: onDismiss)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ManualAttendanceStyle.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(ManualAttendanceStyle.page, in: RoundedRectangle(cornerRadius: 12))
                Button(confirmTitle, action: onConfirm)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(confirmColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Staff avatar

/// The person's photo, or their initials while it loads, when it fails, and when the server sends
/// its generic placeholder (`ic_profile_fall_back`) instead of a photo.
struct ManualAttendanceAvatar: View {
    let name: String
    let imageURL: String?
    var size: CGFloat = 42

    private var url: URL? {
        guard let imageURL,
              !imageURL.trimmingCharacters(in: .whitespaces).isEmpty,
              imageURL.range(of: "fall_back", options: .caseInsensitive) == nil,
              let url = URL(string: imageURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else { return nil }
        return url
    }

    private var initials: String {
        let parts = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            ManualAttendanceStyle.container
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(AppTheme.cerulean)
        }
    }
}

// MARK: - Inline states

struct ManualAttendanceLoadingBlock: View {
    var body: some View {
        ProgressView()
            .tint(AppTheme.cerulean)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
    }
}

struct ManualAttendanceErrorBlock: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.errorRed.opacity(0.7))
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 11)
                .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 11))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
    }
}

struct ManualAttendanceEmptyBlock: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(ManualAttendanceStyle.unmarked.opacity(0.7))
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ManualAttendanceStyle.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }
}

/// The search field both screens share.
struct ManualAttendanceSearchField: View {
    @Binding var text: String
    var placeholder = "Search by name or designation"

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(ManualAttendanceStyle.textMuted)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ManualAttendanceStyle.textFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(ManualAttendanceStyle.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ManualAttendanceStyle.border, lineWidth: 1))
    }
}

/// A filter chip in its status colour: filled when chosen, outlined otherwise.
struct ManualAttendanceChip: View {
    let label: String
    let count: Int
    var tint: Color = AppTheme.cerulean
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : ManualAttendanceStyle.text)
                Text("\(count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(isSelected ? .white : tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        isSelected ? Color.white.opacity(0.22) : tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? tint : Color.white, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? tint : tint.opacity(0.4), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom bar

/// The pinned bar at the foot of both screens. Mirrors Android `BottomActionBar`.
struct ManualAttendanceBottomBar<Summary: View, Content: View>: View {
    @ViewBuilder var summary: () -> Summary
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(ManualAttendanceStyle.border)
                .frame(width: 36, height: 4)
            summary()
            HStack(spacing: 10, content: content)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.white,
            in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
    }
}

extension ManualAttendanceBottomBar where Summary == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(summary: { EmptyView() }, content: content)
    }
}

/// A muted caption over a big figure, with a status pill on the right. Mirrors Android `BarSummary`.
struct ManualAttendanceBarSummary: View {
    let label: String
    let value: String
    var status: String?
    var tone: Color = ManualAttendanceStyle.textMuted

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ManualAttendanceStyle.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(ManualAttendanceStyle.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status {
                Text(status)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(tone)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tone.opacity(0.14), in: Capsule())
            }
        }
    }
}

/// A square tinted button for a secondary action with room only for its icon.
struct ManualAttendanceIconButton: View {
    let icon: String
    let label: String
    var color: Color = AppTheme.cerulean
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
