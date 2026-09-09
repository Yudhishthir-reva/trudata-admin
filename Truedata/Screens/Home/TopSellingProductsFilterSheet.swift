//
//  TopSellingProductsFilterSheet.swift
//  Truedata
//

import SwiftUI

struct TopSellingProductsFilterSheet: View {

    @ObservedObject var viewModel: TopSellingProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: TopSellingProductsFilterCategory = .dateRange
    @State private var draftStartDate: String
    @State private var draftEndDate: String
    @State private var draftDatePreset: OrderInsightsDatePreset
    @State private var draftStaffId: String
    @State private var draftSellerId: String
    @State private var staffSearch = ""
    @State private var sellerSearch = ""
    @State private var sellerStateId: String?

    init(viewModel: TopSellingProductsViewModel) {
        self.viewModel = viewModel
        let filters = viewModel.currentAppliedFilters()
        _draftStartDate = State(initialValue: filters.startDate)
        _draftEndDate = State(initialValue: filters.endDate)
        _draftDatePreset = State(initialValue: filters.datePreset)
        _draftStaffId = State(initialValue: filters.staffId)
        _draftSellerId = State(initialValue: filters.sellerId)
    }

    private var categoryItems: [FilterCategoryItem] {
        TopSellingProductsFilterCategory.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedCategory.rawValue },
            set: { if let value = TopSellingProductsFilterCategory(rawValue: $0) { selectedCategory = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Clear All",
            applyTitle: "Apply",
            showsResetIcon: false,
            showsApplyIcon: false,
            onReset: {
                viewModel.resetToDefaultFilters()
                dismiss()
            },
            onApply: {
                applyDraftFilters()
                dismiss()
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FilterSectionTitle(title: selectedCategory.rawValue)
                    switch selectedCategory {
                    case .dateRange:
                        dateRangeContent
                    case .staff:
                        staffContent
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
            ForEach(OrderInsightsDatePreset.allCases, id: \.self) { preset in
                FilterRadioRow(title: preset.rawValue, isSelected: draftDatePreset == preset) {
                    draftDatePreset = preset
                    if preset != .custom, let range = OrderInsightsDatePreset.dateRange(for: preset) {
                        draftStartDate = range.start
                        draftEndDate = range.end
                    }
                }
            }

            if draftDatePreset == .custom {
                VStack(spacing: 10) {
                    customDateField(title: "Start Date", value: draftStartDate) { draftStartDate = $0 }
                    customDateField(title: "End Date", value: draftEndDate) { draftEndDate = $0 }
                }
                .padding(.top, 8)
            }
        }
    }

    private var staffContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterSearchField(placeholder: "Search staff...", text: $staffSearch, filledBackground: true)
            FilterRadioRow(title: "All Staff", isSelected: draftStaffId.isEmptyString) {
                draftStaffId = ""
            }
            ForEach(filteredStaff) { staff in
                FilterRadioRow(title: staff.name, isSelected: draftStaffId == String(staff.id)) {
                    draftStaffId = String(staff.id)
                }
            }
        }
    }

    private var sellerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isSellerFilterLocked {
                Text("Seller filter is locked for this view.")
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            } else {
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
                        viewModel.loadSellers(
                            isRefresh: true,
                            stateId: sellerStateId,
                            search: query
                        )
                    }

                FilterRadioRow(title: "All Sellers", isSelected: draftSellerId.isEmptyString) {
                    draftSellerId = ""
                }

                ForEach(viewModel.sellerList) { seller in
                    FilterRadioRow(title: seller.displayName, isSelected: draftSellerId == String(seller.id)) {
                        draftSellerId = String(seller.id)
                    }
                }

                if viewModel.sellerCurrentPage < viewModel.sellerLastPage {
                    Button("Load More") {
                        viewModel.loadSellers(
                            isRefresh: false,
                            stateId: sellerStateId,
                            search: sellerSearch
                        )
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !staffSearch.isEmptyString else { return viewModel.staffList }
        return viewModel.staffList.filter {
            $0.name.localizedCaseInsensitiveContains(staffSearch)
        }
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
            TopSellingProductsAppliedFilters(
                startDate: draftStartDate,
                endDate: draftEndDate,
                datePreset: draftDatePreset,
                staffId: draftStaffId,
                sellerId: draftSellerId
            )
        )
    }

    private func statePicker(
        title: String,
        selectedName: String,
        options: [(String, String)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func customDateField(title: String, value: String, onChange: @escaping (String) -> Void) -> some View {
        DashboardDatePickerField(
            dateString: DashboardDateFormat.string(from: OrderInsightsDateFormat.parse(value) ?? Date()),
            onDateSelected: onChange
        )
    }
}
