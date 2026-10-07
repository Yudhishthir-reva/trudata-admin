//
//  AllSourceOrdersFilterSheet.swift
//  Truedata
//

import SwiftUI

struct AllSourceOrdersFilterSheet: View {

    @ObservedObject var viewModel: AllSourceOrdersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftSource: AllSourceOrderSource
    @State private var draftPreset: AllSourceOrdersDatePreset
    @State private var draftStart: String
    @State private var draftEnd: String
    @State private var selectedTab = 0

    init(viewModel: AllSourceOrdersViewModel) {
        self.viewModel = viewModel
        _draftSource = State(initialValue: viewModel.filter.source)
        _draftPreset = State(initialValue: viewModel.filter.preset)
        _draftStart = State(initialValue: viewModel.filter.startDate)
        _draftEnd = State(initialValue: viewModel.filter.endDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Source").tag(0)
                    Text("Date Range").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(16)

                if selectedTab == 0 {
                    sourceList
                } else {
                    dateList
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button("Reset") {
                        draftSource = .all
                        draftPreset = .default
                        if let range = AllSourceOrdersDatePreset.dateRange(for: .default) {
                            draftStart = range.start
                            draftEnd = range.end
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "F3F4F6"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Apply filters") {
                        apply()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(16)
            }
            .background(Color.white)
            .navigationTitle("Filter orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var sourceList: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("ORDER SOURCE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(AllSourceOrderSource.allCases) { source in
                    Button {
                        draftSource = source
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(source.chipColor)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.filterLabel)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                                Text(source.filterDescription)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DashboardTheme.neutralMedium)
                            }
                            Spacer()
                            if draftSource == source {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                            }
                        }
                        .padding(14)
                        .background(draftSource == source ? DashboardTheme.primaryBlue.opacity(0.08) : Color(hex: "F9FAFB"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var dateList: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("DATE RANGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(AllSourceOrdersDatePreset.allCases) { preset in
                    Button {
                        draftPreset = preset
                        if let range = AllSourceOrdersDatePreset.dateRange(for: preset) {
                            draftStart = range.start
                            draftEnd = range.end
                        }
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            Spacer()
                            if draftPreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                            }
                        }
                        .padding(14)
                        .background(draftPreset == preset ? DashboardTheme.primaryBlue.opacity(0.08) : Color(hex: "F9FAFB"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if draftPreset == .custom {
                    HStack(spacing: 10) {
                        dateField(label: "From", dateString: $draftStart)
                        dateField(label: "To", dateString: $draftEnd)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func dateField(label: String, dateString: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        OrderInsightsDateFormat.parse(dateString.wrappedValue) ?? Date()
                    },
                    set: { dateString.wrappedValue = OrderInsightsDateFormat.string(from: $0) }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func apply() {
        let filter = AllSourceOrdersFilter(
            source: draftSource,
            preset: draftPreset,
            startDate: draftStart,
            endDate: draftEnd
        )
        viewModel.applyFilter(filter)
        dismiss()
    }
}
