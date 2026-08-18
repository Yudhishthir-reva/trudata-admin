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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    categorySidebar
                    Divider()
                    categoryContent
                }
                .frame(maxHeight: .infinity)

                footerButtons
            }
            .background(Color(hex: "F3F4F6"))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
        }
    }

    private var categorySidebar: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(TopSellingProductsFilterCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: selectedCategory == category ? .bold : .medium))
                            .foregroundStyle(selectedCategory == category ? .white : DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(
                                selectedCategory == category
                                ? DashboardTheme.primaryBlue
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: 118)
        .background(DashboardTheme.surfaceVariant.opacity(0.5))
    }

    @ViewBuilder
    private var categoryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedCategory.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.bottom, 4)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private var dateRangeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(OrderInsightsDatePreset.allCases, id: \.self) { preset in
                filterRadio(title: preset.rawValue, isSelected: draftDatePreset == preset) {
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
            searchField(placeholder: "Search staff...", text: $staffSearch)
            filterRadio(title: "All Staff", isSelected: draftStaffId.isEmptyString) {
                draftStaffId = ""
            }
            ForEach(filteredStaff) { staff in
                filterRadio(title: staff.name, isSelected: draftStaffId == String(staff.id)) {
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

                searchField(placeholder: "Search sellers...", text: $sellerSearch)
                    .onChange(of: sellerSearch) { _, query in
                        viewModel.loadSellers(
                            isRefresh: true,
                            stateId: sellerStateId,
                            search: query
                        )
                    }

                filterRadio(title: "All Sellers", isSelected: draftSellerId.isEmptyString) {
                    draftSellerId = ""
                }

                ForEach(viewModel.sellerList) { seller in
                    filterRadio(title: seller.displayName, isSelected: draftSellerId == String(seller.id)) {
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

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.resetToDefaultFilters()
                dismiss()
            } label: {
                Text("Clear All")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DashboardTheme.primaryBlue.opacity(0.4), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                applyDraftFilters()
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
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

    private func filterRadio(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func searchField(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(placeholder, text: text)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(hex: "F3F4F6"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
