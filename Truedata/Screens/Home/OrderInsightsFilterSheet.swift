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
        _draftOutOfRange = State(initialValue: filters.outOfRangeIsShow == "2")
        _draftHasRemark = State(initialValue: filters.hasRemark == "1")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                lastUsedFilterCard

                HStack(spacing: 0) {
                    categorySidebar
                    Divider()
                    categoryContent
                }
                .frame(maxHeight: .infinity)

                footerButtons
            }
            .background(Color(hex: "F3F4F6"))
            .navigationTitle("Order Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
        }
    }

    private var lastUsedFilterCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text("Last Used Filter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                Text(viewModel.lastUsedFilterLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .padding(.leading, 20)
            }
            Spacer()
            Button {
                applyDraftFilters()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Apply")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    DashboardTheme.primaryBlue.opacity(0.08),
                    DashboardTheme.secondaryPurple.opacity(0.06)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.15), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var categorySidebar: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(OrderInsightsFilterCategory.allCases, id: \.self) { category in
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
                case .orderStatus:
                    orderStatusContent
                case .staff:
                    staffContent
                case .seller:
                    sellerContent
                case .beat:
                    beatContent
                case .moreOptions:
                    moreOptionsContent
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
                filterRadio(
                    title: preset.rawValue,
                    isSelected: draftDatePreset == preset
                ) {
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
            filterRadio(title: "All Status", isSelected: draftStatus.isEmptyString) {
                draftStatus = ""
            }
            ForEach(viewModel.statusFilterOptions) { item in
                filterRadio(
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

            searchField(placeholder: "Search sellers...", text: $sellerSearch)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(
                        isRefresh: true,
                        stateId: sellerStateId,
                        cityId: sellerCityId,
                        beatId: sellerBeatId,
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
                    filterRadio(title: beat.name, isSelected: draftBeatId == String(beat.id)) {
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

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                draftStartDate = OrderInsightsDateFormat.todayString
                draftEndDate = OrderInsightsDateFormat.todayString
                draftDatePreset = .today
                draftStatus = "0"
                draftStaffId = ""
                draftSellerId = ""
                draftBeatId = ""
                draftOutOfRange = false
                draftHasRemark = false
                viewModel.resetToDefaultFilters()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Use Default")
                }
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
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Apply Filters")
                }
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
                outOfRangeIsShow: draftOutOfRange ? "2" : "",
                hasRemark: draftHasRemark ? "1" : "0"
            )
        )
    }

    private func filterRadio(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .multilineTextAlignment(.leading)
                Spacer()
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
        }
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
