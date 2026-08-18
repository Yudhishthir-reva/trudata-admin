//
//  DashboardDatePicker.swift
//  Truedata
//

import SwiftUI

enum DashboardDateFormat {
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        apiFormatter.date(from: value.trim)
    }

    static func string(from date: Date) -> String {
        apiFormatter.string(from: date)
    }

    static var todayString: String {
        string(from: Date())
    }
}

struct DashboardDatePickerField: View {
    let dateString: String
    var placeholder: String = "Select a date"
    var allowsFutureDates: Bool = false
    var onDateSelected: (String) -> Void

    @State private var showPicker = false

    private var displayText: String {
        dateString.isEmptyString ? placeholder : dateString
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text(displayText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(
                        dateString.isEmptyString
                        ? DashboardTheme.neutralMedium
                        : DashboardTheme.neutralDark
                    )
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DashboardDatePickerSheet(
                initialDate: DashboardDateFormat.parse(dateString) ?? Date(),
                allowsFutureDates: allowsFutureDates,
                onCancel: { showPicker = false },
                onConfirm: { date in
                    onDateSelected(DashboardDateFormat.string(from: date))
                    showPicker = false
                }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct DashboardDatePickerSheet: View {
    let initialDate: Date
    var allowsFutureDates: Bool
    var onCancel: () -> Void
    var onConfirm: (Date) -> Void

    @State private var selectedDate: Date
    @State private var visibleMonth: Date
    @State private var showYearPicker = false

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

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
        _visibleMonth = State(initialValue: initialDate.startOfMonth)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            if showYearPicker {
                yearGrid
            } else {
                weekdayHeader
                dayGrid
            }
            actionButtons
        }
        .padding(16)
        .background(AppTheme.aliceBlue)
    }

    private var header: some View {
        HStack {
            Button {
                visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.cerulean)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showYearPicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(monthYearLabel)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.cerulean)
                    Image(systemName: showYearPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.cerulean)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.cerulean)
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = monthDays(for: visibleMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
        .frame(minHeight: 240)
    }

    private var yearGrid: some View {
        let currentYear = calendar.component(.year, from: visibleMonth)
        let years = Array((currentYear - 12)...(currentYear + 12))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(years, id: \.self) { year in
                let isSelected = year == calendar.component(.year, from: selectedDate)
                Button {
                    if let updated = calendar.date(from: DateComponents(
                        year: year,
                        month: calendar.component(.month, from: visibleMonth),
                        day: min(
                            calendar.component(.day, from: selectedDate),
                            daysInMonth(year: year, month: calendar.component(.month, from: visibleMonth))
                        )
                    )) {
                        selectedDate = updated
                        visibleMonth = updated.startOfMonth
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showYearPicker = false
                    }
                } label: {
                    Text("\(year)")
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.aliceBlue : AppTheme.darkMidnightBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? AppTheme.darkMidnightBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 240)
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.cerulean)
            Button("OK") {
                onConfirm(selectedDate)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(AppTheme.cerulean)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isEnabled = isDateEnabled(date)

        return Button {
            selectedDate = date
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 15, weight: isSelected || isToday ? .bold : .regular))
                .foregroundStyle(
                    !isEnabled
                    ? DashboardTheme.neutralMedium.opacity(0.5)
                    : isSelected ? AppTheme.aliceBlue : AppTheme.darkMidnightBlue
                )
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? AppTheme.darkMidnightBlue : Color.clear)
                .clipShape(Circle())
                .overlay {
                    if isToday && !isSelected {
                        Circle()
                            .stroke(AppTheme.blue, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var monthYearLabel: String {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        let month = monthFormatter.string(from: visibleMonth)
        let year = calendar.component(.year, from: visibleMonth)
        return "\(month) \(year)"
    }

    private func monthDays(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func isDateEnabled(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        if !allowsFutureDates {
            let today = calendar.startOfDay(for: Date())
            if startOfDay > today { return false }
        }
        return true
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }
}

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}
