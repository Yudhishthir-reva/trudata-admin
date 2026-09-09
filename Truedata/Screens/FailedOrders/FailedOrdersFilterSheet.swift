//
//  FailedOrdersFilterSheet.swift
//  Truedata
//

import SwiftUI

struct FailedOrdersFilterSheet: View {

    @ObservedObject var viewModel: FailedOrdersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: FailedOrdersFilterCategory = .dateRange
    @State private var draftStartDate: String
    @State private var draftEndDate: String
    @State private var draftDatePreset: AchievementHistoryDatePreset
    @State private var draftSellerId: String
    @State private var draftRiderId: String
    @State private var riderSearch = ""
    @State private var sellerSearch = ""
    @State private var sellerStateId: String?

    init(viewModel: FailedOrdersViewModel) {
        self.viewModel = viewModel
        let filters = viewModel.currentAppliedFilters()
        _draftStartDate = State(initialValue: filters.startDate)
        _draftEndDate = State(initialValue: filters.endDate)
        _draftDatePreset = State(initialValue: filters.datePreset)
        _draftSellerId = State(initialValue: filters.sellerId)
        _draftRiderId = State(initialValue: filters.riderId)
    }

    private var categoryItems: [FilterCategoryItem] {
        FailedOrdersFilterCategory.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedCategory.rawValue },
            set: { if let value = FailedOrdersFilterCategory(rawValue: $0) { selectedCategory = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Filter Failed Orders",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            accent: DashboardTheme.dangerRed,
            resetTitle: "Clear All",
            applyTitle: "Apply Filters",
            showsResetIcon: false,
            showsApplyIcon: false,
            onReset: {
                draftStartDate = OrderInsightsDateFormat.todayString
                draftEndDate = OrderInsightsDateFormat.todayString
                draftDatePreset = .today
                draftSellerId = ""
                draftRiderId = ""
                viewModel.clearFilters()
                dismiss()
            },
            onApply: {
                applyDraftFilters()
                dismiss()
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FilterSectionTitle(title: selectedCategory.rawValue, accent: DashboardTheme.dangerRed)
                    switch selectedCategory {
                    case .dateRange:
                        dateRangeContent
                    case .rider:
                        riderContent
                    case .seller:
                        sellerContent
                    }
                }
                .padding(12)
            }
        }
    }

    private var dateRangeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(AchievementHistoryDatePreset.allCases, id: \.self) { preset in
                FilterRadioRow(
                    title: preset.rawValue,
                    isSelected: draftDatePreset == preset,
                    accent: DashboardTheme.dangerRed
                ) {
                    draftDatePreset = preset
                    if preset != .custom, let range = AchievementHistoryDatePreset.dateRange(for: preset) {
                        draftStartDate = range.start
                        draftEndDate = range.end
                    }
                }
            }
            if draftDatePreset == .custom {
                VStack(spacing: 10) {
                    DashboardDatePickerField(dateString: draftStartDate, onDateSelected: { draftStartDate = $0 })
                    DashboardDatePickerField(dateString: draftEndDate, onDateSelected: { draftEndDate = $0 })
                }
            }
        }
    }

    private var riderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterSearchField(placeholder: "Search rider...", text: $riderSearch, filledBackground: true)
            FilterRadioRow(
                title: "All Riders",
                isSelected: draftRiderId.isEmptyString,
                accent: DashboardTheme.dangerRed
            ) { draftRiderId = "" }
            ForEach(filteredRiders) { rider in
                FilterRadioRow(
                    title: rider.name,
                    isSelected: draftRiderId == String(rider.id),
                    accent: DashboardTheme.dangerRed
                ) {
                    draftRiderId = String(rider.id)
                }
            }
            if viewModel.isLoadingStaff {
                ProgressView().tint(DashboardTheme.dangerRed)
            }
        }
    }

    private var sellerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            statePicker(
                title: "State",
                selectedName: sellerStateName,
                options: viewModel.areaStates.map { ($0.name, String($0.id)) },
                onSelect: { id in
                    sellerStateId = id
                    viewModel.loadSellers(isRefresh: true, stateId: id, search: sellerSearch)
                }
            )
            FilterSearchField(placeholder: "Search sellers...", text: $sellerSearch, filledBackground: true)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(isRefresh: true, stateId: sellerStateId, search: query)
                }
            FilterRadioRow(
                title: "All Sellers",
                isSelected: draftSellerId.isEmptyString,
                accent: DashboardTheme.dangerRed
            ) { draftSellerId = "" }
            ForEach(viewModel.sellerList) { seller in
                FilterRadioRow(
                    title: seller.displayName.isEmptyString ? "Seller #\(seller.id)" : seller.displayName,
                    isSelected: draftSellerId == String(seller.id),
                    accent: DashboardTheme.dangerRed
                ) {
                    draftSellerId = String(seller.id)
                }
            }
            if viewModel.isLoadingSellers {
                ProgressView().tint(DashboardTheme.dangerRed)
            }
        }
    }

    private var filteredRiders: [OrderInsightsStaffMember] {
        guard !riderSearch.isEmptyString else { return viewModel.staffList }
        return viewModel.staffList.filter { $0.name.localizedCaseInsensitiveContains(riderSearch) }
    }

    private var sellerStateName: String {
        guard let sellerStateId,
              let state = viewModel.areaStates.first(where: { String($0.id) == sellerStateId }) else {
            return "All States"
        }
        return state.name
    }

    private func applyDraftFilters() {
        viewModel.applyFilters(
            FailedOrdersAppliedFilters(
                startDate: draftStartDate,
                endDate: draftEndDate,
                datePreset: draftDatePreset,
                sellerId: draftSellerId,
                riderId: draftRiderId
            )
        )
    }

    private func statePicker(
        title: String,
        selectedName: String,
        options: [(String, String)],
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button("All States") { onSelect(nil) }
            ForEach(options, id: \.1) { option in
                Button(option.0) { onSelect(option.1) }
            }
        } label: {
            HStack {
                Text("\(title): \(selectedName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
