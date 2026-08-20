//
//  AttendanceCommonViews.swift
//  Truedata
//

import SwiftUI

enum AttendanceRequestTab: String, CaseIterable, Identifiable {
    case approved = "Approved"
    case pending = "Pending"
    case rejected = "Rejected"

    var id: String { rawValue }

    var indicatorColor: Color {
        switch self {
        case .approved: return DashboardTheme.successGreen
        case .pending: return DashboardTheme.warningYellow
        case .rejected: return DashboardTheme.dangerRed
        }
    }
}

enum AttendanceAPIDateFormat {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func parse(_ value: String) -> Date? {
        formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct AttendanceRequestTabBar: View {
    @Binding var selectedTab: AttendanceRequestTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AttendanceRequestTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? DashboardTheme.primaryBlue : AppTheme.aliceBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct AttendanceListCard: View {
    let indicatorColor: Color
    let lines: [String]

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(indicatorColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: index == 0 ? 15 : 14, weight: index == 0 ? .bold : .regular))
                        .foregroundStyle(index == 0 ? .black : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

struct AttendanceFloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(DashboardTheme.primaryBlue)
                .clipShape(Circle())
                .shadow(color: DashboardTheme.primaryBlue.opacity(0.35), radius: 8, y: 4)
        }
    }
}

struct AttendanceDatePickerField: View {
    let label: String
    let dateString: String
    var placeholder: String = "Select a date"
    var allowsFutureDates: Bool = false
    var onDateSelected: (String) -> Void

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(dateString.isEmpty ? placeholder : dateString)
                        .font(.system(size: 15))
                        .foregroundStyle(dateString.isEmpty ? AppTheme.textSecondary : AppTheme.darkMidnightBlue)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.cerulean)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(AppTheme.aliceBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            AttendanceDatePickerSheet(
                initialDate: AttendanceAPIDateFormat.parse(dateString) ?? Date(),
                allowsFutureDates: allowsFutureDates,
                onCancel: { showPicker = false },
                onConfirm: { date in
                    onDateSelected(AttendanceAPIDateFormat.string(from: date))
                    showPicker = false
                }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct AttendanceDatePickerSheet: View {
    let initialDate: Date
    var allowsFutureDates: Bool
    var onCancel: () -> Void
    var onConfirm: (Date) -> Void

    @State private var selectedDate: Date

    init(
        initialDate: Date,
        allowsFutureDates: Bool,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Date) -> Void
    ) {
        self.initialDate = initialDate
        self.allowsFutureDates = allowsFutureDates
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select date",
                    selection: $selectedDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 8)

                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { onConfirm(selectedDate) }
                }
            }
        }
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
        if allowsFutureDates {
            let end = calendar.date(byAdding: .year, value: 5, to: Date()) ?? Date()
            return start...end
        }
        return start...Date()
    }
}

struct AttendancePickerField: View {
    let label: String
    let value: String
    var placeholder: String = "Choose option"
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            Button(action: onTap) {
                HStack {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.system(size: 15))
                        .foregroundStyle(value.isEmpty ? AppTheme.textSecondary : AppTheme.darkMidnightBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.cerulean)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(AppTheme.aliceBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct AttendanceOptionPickerSheet: View {
    let title: String
    let options: [String]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        guard !search.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                    dismiss()
                }
                .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
