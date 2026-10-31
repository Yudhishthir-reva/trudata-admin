//
//  PaymentInsightsFilterSheet.swift
//  Truedata
//

import SwiftUI

struct PaymentInsightsFilterSheet: View {

    @ObservedObject var viewModel: PaymentInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: PaymentInsightsFilterCategory = .dateRange
    @State private var draftStartDate: String
    @State private var draftEndDate: String
    @State private var draftDatePreset: OrderInsightsDatePreset
    @State private var draftPaymentMode: String
    @State private var draftPaymentStatus: String
    @State private var draftStaffId: String
    @State private var draftSellerId: String
    @State private var draftSellerName: String
    @State private var staffSearch = ""
    @State private var sellerSearch = ""
    @State private var sellerStateId: String?

    init(viewModel: PaymentInsightsViewModel) {
        self.viewModel = viewModel
        let filters = viewModel.currentAppliedFilters()
        _draftStartDate = State(initialValue: filters.startDate)
        _draftEndDate = State(initialValue: filters.endDate)
        _draftDatePreset = State(initialValue: filters.datePreset)
        _draftPaymentMode = State(initialValue: filters.paymentMode)
        _draftPaymentStatus = State(initialValue: filters.paymentStatus)
        _draftStaffId = State(initialValue: filters.staffId)
        _draftSellerId = State(initialValue: filters.sellerId)
        _draftSellerName = State(initialValue: filters.sellerName)
    }

    /// A stored yyyy-MM-dd date as the picker shows it (dd-MM-yyyy); blank stays blank.
    private func pickerText(_ api: String) -> String {
        OrderInsightsDateFormat.parse(api).map { DashboardDateFormat.string(from: $0) } ?? api
    }

    private var categoryItems: [FilterCategoryItem] {
        PaymentInsightsFilterCategory.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedCategory.rawValue },
            set: { if let value = PaymentInsightsFilterCategory(rawValue: $0) { selectedCategory = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Filters · Report & Bills",
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
                    case .paymentMode:
                        paymentModeContent
                    case .paymentStatus:
                        paymentStatusContent
                    case .staff:
                        staffContent
                    case .seller:
                        sellerContent
                    }
                }
                .padding(12)
            }
        }
        // The seller list is shared with the Settlements sheet, which may have left it narrowed
        // to a search; start this sheet from the full list.
        .onAppear { viewModel.loadSellers(isRefresh: true) }
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
                    // The picker reads and writes dd-MM-yyyy, but start_date / end_date go to the
                    // API as yyyy-MM-dd like every preset does; writing the picker's form straight
                    // through sent the wrong format for custom ranges.
                    DashboardDatePickerField(dateString: pickerText(draftStartDate),
                                             onDateSelected: { draftStartDate = OrderInsightsDateFormat.normalizedAPIString(from: $0) })
                    DashboardDatePickerField(dateString: pickerText(draftEndDate),
                                             onDateSelected: { draftEndDate = OrderInsightsDateFormat.normalizedAPIString(from: $0) })
                }
            }
        }
    }

    private var paymentModeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PaymentInsightsPaymentMode.options) { option in
                FilterRadioRow(title: option.title, isSelected: draftPaymentMode == option.id) {
                    draftPaymentMode = option.id
                }
            }
        }
    }

    private var paymentStatusContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PaymentInsightsPaymentStatus.options) { option in
                FilterRadioRow(title: option.title, isSelected: draftPaymentStatus == option.id) {
                    draftPaymentStatus = option.id
                }
            }
        }
    }

    private var staffContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterSearchField(placeholder: "Search staff...", text: $staffSearch, filledBackground: true)
            FilterRadioRow(title: "All Staff", isSelected: draftStaffId.isEmptyString) { draftStaffId = "" }
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
                    viewModel.loadSellers(isRefresh: true, stateId: id, search: sellerSearch)
                }
            )
            FilterSearchField(placeholder: "Search sellers...", text: $sellerSearch, filledBackground: true)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(isRefresh: true, stateId: sellerStateId, search: query)
                }
            FilterRadioRow(title: "All Sellers", isSelected: draftSellerId.isEmptyString) {
                draftSellerId = ""
                draftSellerName = ""
            }
            ForEach(viewModel.sellerList) { seller in
                FilterRadioRow(title: seller.displayName, isSelected: draftSellerId == String(seller.id)) {
                    draftSellerId = String(seller.id)
                    draftSellerName = seller.displayName
                }
            }
            if viewModel.sellerCurrentPage < viewModel.sellerLastPage {
                Button("Load More") {
                    viewModel.loadSellers(isRefresh: false, stateId: sellerStateId, search: sellerSearch)
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

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !staffSearch.isEmptyString else { return viewModel.staffList }
        return viewModel.staffList.filter { $0.name.localizedCaseInsensitiveContains(staffSearch) }
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
            PaymentInsightsAppliedFilters(
                startDate: draftStartDate,
                endDate: draftEndDate,
                datePreset: draftDatePreset,
                paymentMode: draftPaymentMode,
                paymentStatus: draftPaymentStatus,
                staffId: draftStaffId,
                sellerId: draftSellerId,
                sellerName: draftSellerName
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
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundStyle(DashboardTheme.neutralDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Settlements filter sheet

/// A seller the Settlements filter can narrow to. Label as Android: shop and owner, deduped.
private struct PaymentSettlementSellerChoice: Identifiable {
    let id: String
    let label: String

    init(_ seller: OrderInsightsSellerItem) {
        id = String(seller.id)
        var names: [String] = []
        for name in [seller.shopName.trim, seller.name.trim] where !name.isEmpty && !names.contains(name) {
            names.append(name)
        }
        label = names.isEmpty ? "Seller \(seller.id)" : names.joined(separator: " · ")
    }
}

/// The Settlements tab's own filters (Android `SettlementFilterSheet`): what
/// bill-settlement-history can narrow by — date, mode, seller. Nothing here touches the Report
/// and Bills filters.
struct PaymentSettlementFilterSheet: View {

    @ObservedObject var viewModel: PaymentInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PaymentSettlementFilters
    @State private var sellerQuery = ""

    init(viewModel: PaymentInsightsViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.settlementFilters)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettlementSheetSection(title: "Settled on") { dateContent }
                    SettlementSheetSection(title: "Payment mode") { modeContent }
                    SettlementSheetSection(title: "Seller") { sellerContent }
                }
                .padding(.bottom, 8)
            }
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color.white.ignoresSafeArea())
        // Shared with the Report & Bills sheet; start from the unsearched list.
        .onAppear { viewModel.loadSellers(isRefresh: true) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Filter settlements")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text("Only changes the Settlements tab. Report and Bills keep their own filters.")
                .font(.system(size: 12.5))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }

    // MARK: Date

    private var dateContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 6) {
                ForEach(OrderInsightsDatePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    SettlementSheetChip(label: preset.rawValue, isOn: draft.datePreset == preset) {
                        draft.datePreset = preset
                    }
                }
                SettlementSheetChip(
                    label: draft.datePreset == .custom
                        ? PaymentInsightsFilterSummary.dateLabel(preset: .custom, start: draft.startDate, end: draft.endDate)
                        : "Custom…",
                    isOn: draft.datePreset == .custom
                ) {
                    selectCustomRange()
                }
            }
            if draft.datePreset == .custom {
                customRangeFields
            }
        }
    }

    /// Android opens a range calendar here; iOS uses the app's own From/To day pickers inline,
    /// which also keep future days out.
    private var customRangeFields: some View {
        HStack(spacing: 10) {
            rangeField(title: "From", value: draft.startDate) { picked in
                draft.startDate = picked
                if let end = OrderInsightsDateFormat.parse(draft.endDate),
                   let start = OrderInsightsDateFormat.parse(picked), start > end {
                    draft.endDate = picked
                }
            }
            rangeField(title: "To", value: draft.endDate) { picked in
                draft.endDate = picked
                if let start = OrderInsightsDateFormat.parse(draft.startDate),
                   let end = OrderInsightsDateFormat.parse(picked), end < start {
                    draft.startDate = picked
                }
            }
        }
    }

    private func rangeField(title: String, value: String, onPick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
            // The picker reads and writes dd-MM-yyyy; the API takes yyyy-MM-dd.
            DashboardDatePickerField(
                dateString: OrderInsightsDateFormat.parse(value).map { DashboardDateFormat.string(from: $0) } ?? ""
            ) { picked in
                onPick(OrderInsightsDateFormat.normalizedAPIString(from: picked))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Starts the custom range on whatever the current preset covers, so the fields aren't blank.
    private func selectCustomRange() {
        guard draft.datePreset != .custom else { return }
        if let range = OrderInsightsDatePreset.dateRange(for: draft.datePreset) {
            draft.startDate = range.start
            draft.endDate = range.end
        }
        draft.datePreset = .custom
    }

    // MARK: Mode

    private var modeContent: some View {
        FlowLayout(spacing: 6) {
            SettlementSheetChip(label: "All modes", isOn: draft.paymentType.isEmptyString) {
                draft.paymentType = ""
            }
            ForEach(PaymentInsightsFilterSummary.modeLabels, id: \.key) { mode in
                SettlementSheetChip(label: mode.label, isOn: draft.paymentType == mode.key) {
                    draft.paymentType = mode.key
                }
            }
        }
    }

    // MARK: Seller

    private var sellers: [PaymentSettlementSellerChoice] {
        viewModel.sellerList
            .filter { $0.id > 0 }
            .map { PaymentSettlementSellerChoice($0) }
            .sorted { $0.label.lowercased() < $1.label.lowercased() }
    }

    /// Android shows 30 unsearched and up to 60 matches. The list here is the server's paged
    /// seller list (searched server-side as you type), filtered locally too so the rows react
    /// before the response lands.
    private var shownSellers: [PaymentSettlementSellerChoice] {
        let query = sellerQuery.trim.lowercased()
        guard !query.isEmpty else { return Array(sellers.prefix(30)) }
        return Array(sellers.filter { $0.label.lowercased().contains(query) }.prefix(60))
    }

    private var sellerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !draft.sellerId.isEmptyString {
                pickedSellerRow
            }
            FilterSearchField(placeholder: "Search shop or owner", text: $sellerQuery)
                .onChange(of: sellerQuery) { _, query in
                    viewModel.loadSellers(isRefresh: true, search: query.trim)
                }
            sellerList
            let total = max(viewModel.sellerTotal, sellers.count)
            if sellerQuery.trim.isEmpty, total > shownSellers.count {
                Text("Search to find any of \(total) sellers.")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
    }

    /// Named from the stored choice, so it still reads right when a search has scrolled the
    /// seller out of the loaded list.
    private var pickedSellerRow: some View {
        HStack(spacing: 8) {
            Text(draft.sellerName.isEmptyString ? "1 seller" : draft.sellerName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("All sellers") { pickSeller(nil) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(DashboardTheme.primaryBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var sellerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shownSellers) { seller in
                    SettlementSellerRow(label: seller.label, isOn: seller.id == draft.sellerId) {
                        pickSeller(seller.id == draft.sellerId ? nil : seller)
                    }
                }
                if shownSellers.isEmpty {
                    Text(sellers.isEmpty && sellerQuery.trim.isEmpty
                         ? "Seller list is still loading."
                         : "No seller matches “\(sellerQuery)”.")
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func pickSeller(_ seller: PaymentSettlementSellerChoice?) {
        draft.sellerId = seller?.id ?? ""
        draft.sellerName = seller?.label ?? ""
    }

    // MARK: Footer

    /// Reset takes a third, "Show settlements" two thirds, as Android's 1f / 2f weights.
    private var footer: some View {
        BillWeightedRow(spacing: 10) {
            Button {
                viewModel.resetSettlementFilters()
                dismiss()
            } label: {
                Text("Reset")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DashboardTheme.neutralMedium.opacity(0.4), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .billWeight(1)

            Button {
                viewModel.applySettlementFilters(draft)
                dismiss()
            } label: {
                Text("Show settlements")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .billWeight(2)
        }
    }
}

private struct SettlementSheetSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            content()
        }
    }
}

private struct SettlementSheetChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 12.5, weight: isOn ? .bold : .medium))
            }
            .foregroundStyle(isOn ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn ? DashboardTheme.primaryBlue.opacity(0.1) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOn ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettlementSellerRow: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 13.5, weight: isOn ? .bold : .regular))
                    .foregroundStyle(isOn ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
