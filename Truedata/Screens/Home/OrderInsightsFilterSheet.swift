//
//  OrderInsightsFilterSheet.swift
//  Truedata
//

import SwiftUI

struct OrderInsightsFilterSheet: View {

    @ObservedObject var viewModel: OrderInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: OrderInsightsFilterCategory = .dateRange
    @State private var draftStartDate: String
    @State private var draftEndDate: String
    @State private var draftDatePreset: OrderInsightsDatePreset
    @State private var draftStatus: String
    @State private var draftStaffId: String
    @State private var draftSellerId: String
    @State private var draftBeatId: String
    @State private var draftOrderSource: String
    @State private var draftOutOfRange: Bool
    @State private var draftHasRemark: Bool
    @State private var staffSearch = ""
    @State private var sellerSearch = ""
    @State private var beatStateId: Int?
    @State private var beatCityId: Int?
    @State private var sellerStateId: String?
    @State private var sellerCityId: String?
    @State private var sellerBeatId: String?

    init(viewModel: OrderInsightsViewModel) {
        self.viewModel = viewModel
        let filters = viewModel.currentAppliedFilters()
        _draftStartDate = State(initialValue: filters.startDate)
        _draftEndDate = State(initialValue: filters.endDate)
        _draftDatePreset = State(initialValue: filters.datePreset)
        _draftStatus = State(initialValue: filters.orderStatus)
        _draftStaffId = State(initialValue: filters.staffId)
        _draftSellerId = State(initialValue: filters.sellerId)
        _draftBeatId = State(initialValue: filters.beatId)
        _draftOrderSource = State(initialValue: filters.orderSource)
        _draftOutOfRange = State(initialValue: filters.outOfRangeIsShow == "2")
        _draftHasRemark = State(initialValue: filters.hasRemark == "1")
    }

    private var categoryItems: [FilterCategoryItem] {
        OrderInsightsFilterCategory.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedCategory.rawValue },
            set: { if let value = OrderInsightsFilterCategory(rawValue: $0) { selectedCategory = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Order Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Use Default",
            applyTitle: "Apply Filters",
            onReset: {
                draftStartDate = OrderInsightsDateFormat.todayString
                draftEndDate = OrderInsightsDateFormat.todayString
                draftDatePreset = .today
                draftStatus = "0"
                draftStaffId = ""
                draftSellerId = ""
                draftBeatId = ""
                draftOrderSource = ""
                draftOutOfRange = false
                draftHasRemark = false
                viewModel.resetToDefaultFilters()
                dismiss()
            },
            onApply: {
                applyDraftFilters()
                dismiss()
            },
            banner: {
                FilterLastUsedBanner(label: viewModel.lastUsedFilterLabel) {
                    viewModel.applyLastUsedFilter()
                    dismiss()
                }
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        FilterSectionTitle(title: selectedCategory.rawValue)
                        switch selectedCategory {
                        case .dateRange:
                            dateRangeContent
                        case .orderStatus:
                            orderStatusContent
                        case .staff:
                            staffContent
                        case .seller:
                            sellerContent
                        case .beat:
                            beatContent
                        case .orderSource:
                            orderSourceContent
                        case .moreOptions:
                            moreOptionsContent
                        }
                    }
                    .padding(12)
                }
            }
        )
    }

    private var orderSourceContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterRadioRow(title: "All Sources", isSelected: draftOrderSource.isEmptyString) {
                draftOrderSource = ""
            }
            FilterRadioRow(title: "By Retailer", isSelected: draftOrderSource == "retailer") {
                draftOrderSource = "retailer"
            }
            FilterRadioRow(
                title: "By Salesperson",
                isSelected: draftOrderSource == "sales_person" || draftOrderSource == "salesperson"
            ) {
                draftOrderSource = "sales_person"
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
                    Text("Custom Date Range")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    customDateField(title: "Start Date", value: draftStartDate) { draftStartDate = $0 }
                    customDateField(title: "End Date", value: draftEndDate) { draftEndDate = $0 }
                }
                .padding(.top, 8)
            }
        }
    }

    private var orderStatusContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterRadioRow(title: "All Status", isSelected: draftStatus.isEmptyString) {
                draftStatus = ""
            }
            ForEach(viewModel.statusFilterOptions) { item in
                FilterRadioRow(
                    title: "\(item.statusLabel) (\(item.count))",
                    isSelected: draftStatus == item.status
                ) {
                    draftStatus = item.status
                }
            }
        }
    }

    private var staffContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterSearchField(placeholder: "Search staff...", text: $staffSearch)
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
            statePicker(
                title: "State",
                selectedName: sellerStateName,
                options: viewModel.areaStates.map { ($0.name, String($0.id)) },
                onSelect: { id in
                    sellerStateId = id
                    sellerCityId = nil
                    sellerBeatId = nil
                    viewModel.loadSellers(isRefresh: true, stateId: id, search: sellerSearch)
                }
            )

            FilterSearchField(placeholder: "Search sellers...", text: $sellerSearch)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(
                        isRefresh: true,
                        stateId: sellerStateId,
                        cityId: sellerCityId,
                        beatId: sellerBeatId,
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
                        cityId: sellerCityId,
                        beatId: sellerBeatId,
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

    private var beatContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            statePicker(
                title: "State",
                selectedName: beatStateName,
                options: viewModel.areaStates.map { ($0.name, String($0.id)) },
                onSelect: { id in
                    beatStateId = Int(id)
                    beatCityId = nil
                    draftBeatId = ""
                }
            )

            if let stateId = beatStateId,
               let state = viewModel.areaStates.first(where: { $0.id == stateId }) {
                statePicker(
                    title: "City",
                    selectedName: beatCityName,
                    options: state.cities.map { ($0.name, String($0.id)) },
                    onSelect: { id in
                        beatCityId = Int(id)
                        draftBeatId = ""
                    }
                )
            }

            if let stateId = beatStateId, let cityId = beatCityId,
               let city = viewModel.areaStates.first(where: { $0.id == stateId })?.cities.first(where: { $0.id == cityId }) {
                ForEach(city.beats) { beat in
                    FilterRadioRow(title: beat.name, isSelected: draftBeatId == String(beat.id)) {
                        draftBeatId = String(beat.id)
                    }
                }
            }
        }
    }

    private var moreOptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleRow(title: "Show Out of Range Orders Only", isOn: $draftOutOfRange)
            toggleRow(title: "Show Orders Only With Remarks", isOn: $draftHasRemark)
        }
    }

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !staffSearch.isEmptyString else { return viewModel.staffList }
        return viewModel.staffList.filter {
            $0.name.localizedCaseInsensitiveContains(staffSearch)
        }
    }

    private var sellerStateName: String {
        guard let id = sellerStateId,
              let state = viewModel.areaStates.first(where: { String($0.id) == id }) else {
            return "All States"
        }
        return state.name
    }

    private var beatStateName: String {
        guard let id = beatStateId,
              let state = viewModel.areaStates.first(where: { $0.id == id }) else {
            return "All States"
        }
        return state.name
    }

    private var beatCityName: String {
        guard let stateId = beatStateId, let cityId = beatCityId,
              let city = viewModel.areaStates.first(where: { $0.id == stateId })?.cities.first(where: { $0.id == cityId }) else {
            return "All Cities"
        }
        return city.name
    }

    private func applyDraftFilters() {
        viewModel.applyFilters(
            OrderInsightsAppliedFilters(
                startDate: draftStartDate,
                endDate: draftEndDate,
                datePreset: draftDatePreset,
                orderStatus: draftStatus,
                staffId: draftStaffId,
                sellerId: draftSellerId,
                beatId: draftBeatId,
                orderSource: draftOrderSource,
                outOfRangeIsShow: draftOutOfRange ? "2" : "",
                hasRemark: draftHasRemark ? "1" : "0"
            )
        )
    }

    private func customDateField(title: String, value: String, onSelect: @escaping (String) -> Void) -> some View {
        DashboardDatePickerField(
            dateString: DashboardDateFormat.string(from: OrderInsightsDateFormat.parse(value) ?? Date()),
            placeholder: title,
            onDateSelected: { selected in
                onSelect(OrderInsightsDateFormat.normalizedAPIString(from: selected))
            }
        )
    }

    private func statePicker(
        title: String,
        selectedName: String,
        options: [(String, String)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            Button("All \(title)s") { onSelect("") }
            ForEach(options, id: \.1) { option in
                Button(option.0) { onSelect(option.1) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                HStack {
                    Text(selectedName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1)
                }
            }
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .tint(DashboardTheme.primaryBlue)
    }
}
