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
            .navigationTitle("Filter Failed Orders")
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
                ForEach(FailedOrdersFilterCategory.allCases, id: \.self) { category in
                    Button { selectedCategory = category } label: {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: selectedCategory == category ? .bold : .medium))
                            .foregroundStyle(selectedCategory == category ? .white : DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(
                                selectedCategory == category
                                    ? DashboardTheme.dangerRed
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: 128)
        .background(DashboardTheme.surfaceVariant.opacity(0.5))
    }

    @ViewBuilder
    private var categoryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedCategory.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.dangerRed)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private var dateRangeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(AchievementHistoryDatePreset.allCases, id: \.self) { preset in
                filterRadio(title: preset.rawValue, isSelected: draftDatePreset == preset) {
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
            searchField(placeholder: "Search rider...", text: $riderSearch)
            filterRadio(title: "All Riders", isSelected: draftRiderId.isEmptyString) { draftRiderId = "" }
            ForEach(filteredRiders) { rider in
                filterRadio(title: rider.name, isSelected: draftRiderId == String(rider.id)) {
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
            searchField(placeholder: "Search sellers...", text: $sellerSearch)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(isRefresh: true, stateId: sellerStateId, search: query)
                }
            filterRadio(title: "All Sellers", isSelected: draftSellerId.isEmptyString) { draftSellerId = "" }
            ForEach(viewModel.sellerList) { seller in
                filterRadio(
                    title: seller.displayName.isEmptyString ? "Seller #\(seller.id)" : seller.displayName,
                    isSelected: draftSellerId == String(seller.id)
                ) {
                    draftSellerId = String(seller.id)
                }
            }
            if viewModel.isLoadingSellers {
                ProgressView().tint(DashboardTheme.dangerRed)
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                draftStartDate = OrderInsightsDateFormat.todayString
                draftEndDate = OrderInsightsDateFormat.todayString
                draftDatePreset = .today
                draftSellerId = ""
                draftRiderId = ""
                viewModel.clearFilters()
                dismiss()
            } label: {
                Text("Clear All")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.dangerRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DashboardTheme.dangerRed, lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)

            Button {
                applyDraftFilters()
                dismiss()
            } label: {
                Text("Apply Filters")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DashboardTheme.dangerRed)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
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

    private func filterRadio(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? DashboardTheme.dangerRed : DashboardTheme.neutralMedium)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? DashboardTheme.dangerRed : DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func searchField(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "F3F4F6"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
